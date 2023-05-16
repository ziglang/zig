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

const Zir = @import("Zir.zig");
const refToIndex = Zir.refToIndex;
const indexToRef = Zir.indexToRef;
const trace = @import("tracy.zig").trace;
const BuiltinFn = @import("BuiltinFn.zig");

gpa: Allocator,
tree: *const Ast,
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
/// Maps string table indexes to the first `@import` ZIR instruction
/// that uses this string as the operand.
imports: std.AutoArrayHashMapUnmanaged(u32, Ast.TokenIndex) = .{},
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
    const result = @intCast(u32, astgen.extra.items.len);
    astgen.extra.items.len += fields.len;
    setExtra(astgen, result, extra);
    return result;
}

fn setExtra(astgen: *AstGen, index: usize, extra: anytype) void {
    const fields = std.meta.fields(@TypeOf(extra));
    var i = index;
    inline for (fields) |field| {
        astgen.extra.items[i] = switch (field.type) {
            u32 => @field(extra, field.name),
            Zir.Inst.Ref => @enumToInt(@field(extra, field.name)),
            i32 => @bitCast(u32, @field(extra, field.name)),
            Zir.Inst.Call.Flags => @bitCast(u32, @field(extra, field.name)),
            Zir.Inst.BuiltinCall.Flags => @bitCast(u32, @field(extra, field.name)),
            Zir.Inst.SwitchBlock.Bits => @bitCast(u32, @field(extra, field.name)),
            Zir.Inst.FuncFancy.Bits => @bitCast(u32, @field(extra, field.name)),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
}

fn reserveExtra(astgen: *AstGen, size: usize) Allocator.Error!u32 {
    const result = @intCast(u32, astgen.extra.items.len);
    try astgen.extra.resize(astgen.gpa, result + size);
    return result;
}

fn appendRefs(astgen: *AstGen, refs: []const Zir.Inst.Ref) !void {
    const coerced = @ptrCast([]const u32, refs);
    return astgen.extra.appendSlice(astgen.gpa, coerced);
}

fn appendRefsAssumeCapacity(astgen: *AstGen, refs: []const Zir.Inst.Ref) void {
    const coerced = @ptrCast([]const u32, refs);
    astgen.extra.appendSliceAssumeCapacity(coerced);
}

pub fn generate(gpa: Allocator, tree: Ast) Allocator.Error!Zir {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var astgen: AstGen = .{
        .gpa = gpa,
        .arena = arena.allocator(),
        .tree = &tree,
    };
    defer astgen.deinit(gpa);

    // String table indexes 0, 1, 2 are reserved for special meaning.
    try astgen.string_bytes.appendSlice(gpa, &[_]u8{ 0, 0, 0 });

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
            .Auto,
            0,
        )) |struct_decl_ref| {
            assert(refToIndex(struct_decl_ref).? == 0);
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {}, // Handled via compile_errors below.
        }
    } else {
        try lowerAstErrors(&astgen);
    }

    const err_index = @enumToInt(Zir.ExtraIndex.compile_errors);
    if (astgen.compile_errors.items.len == 0) {
        astgen.extra.items[err_index] = 0;
    } else {
        try astgen.extra.ensureUnusedCapacity(gpa, 1 + astgen.compile_errors.items.len *
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
        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Imports).Struct.fields.len +
            astgen.imports.count() * @typeInfo(Zir.Inst.Imports.Item).Struct.fields.len);

        astgen.extra.items[imports_index] = astgen.addExtraAssumeCapacity(Zir.Inst.Imports{
            .imports_len = @intCast(u32, astgen.imports.count()),
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
        /// The expression must generate a pointer rather than a value. For example, the left hand side
        /// of an assignment uses this kind of result location.
        ref,
        /// The expression will be coerced into this type, but it will be evaluated as an rvalue.
        ty: Zir.Inst.Ref,
        /// Same as `ty` but it is guaranteed that Sema will additionally perform the coercion,
        /// so no `as` instruction needs to be emitted.
        coerced_ty: Zir.Inst.Ref,
        /// The expression must store its result into this typed pointer. The result instruction
        /// from the expression must be ignored.
        ptr: PtrResultLoc,
        /// The expression must store its result into this allocation, which has an inferred type.
        /// The result instruction from the expression must be ignored.
        /// Always an instruction with tag `alloc_inferred`.
        inferred_ptr: Zir.Inst.Ref,
        /// There is a pointer for the expression to store its result into, however, its type
        /// is inferred based on peer type resolution for a `Zir.Inst.Block`.
        /// The result instruction from the expression must be ignored.
        block_ptr: *GenZir,

        const PtrResultLoc = struct {
            inst: Zir.Inst.Ref,
            src_node: ?Ast.Node.Index = null,
        };

        const Strategy = struct {
            elide_store_to_block_ptr_instructions: bool,
            tag: Tag,

            const Tag = enum {
                /// Both branches will use break_void; result location is used to communicate the
                /// result instruction.
                break_void,
                /// Use break statements to pass the block result value, and call rvalue() at
                /// the end depending on rl. Also elide the store_to_block_ptr instructions
                /// depending on rl.
                break_operand,
            };
        };

        fn strategy(rl: Loc, block_scope: *GenZir) Strategy {
            switch (rl) {
                // In this branch there will not be any store_to_block_ptr instructions.
                .none, .ty, .coerced_ty, .ref => return .{
                    .tag = .break_operand,
                    .elide_store_to_block_ptr_instructions = false,
                },
                .discard => return .{
                    .tag = .break_void,
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

const align_ri: ResultInfo = .{ .rl = .{ .ty = .u29_type } };
const coerced_align_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .u29_type } };
const bool_ri: ResultInfo = .{ .rl = .{ .ty = .bool_type } };
const type_ri: ResultInfo = .{ .rl = .{ .ty = .type_type } };
const coerced_type_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .type_type } };

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
            const result = try gz.addPlNode(.array_mul, node, Zir.Inst.Bin{
                .lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs),
                .rhs = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[node].rhs),
            });
            return rvalue(gz, ri, result, node);
        },

        .error_union      => return simpleBinOp(gz, scope, ri, node, .error_union_type),
        .merge_error_sets => return simpleBinOp(gz, scope, ri, node, .merge_error_sets),

        .bool_and => return boolBinOp(gz, scope, ri, node, .bool_br_and),
        .bool_or  => return boolBinOp(gz, scope, ri, node, .bool_br_or),

        .bool_not => return simpleUnOp(gz, scope, ri, node, bool_ri, node_datas[node].lhs, .bool_not),
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
        => return ifExpr(gz, scope, ri.br(), node, tree.fullIf(node).?),

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
                .ref => return lhs,
                else => {
                    const result = try gz.addUnNode(.load, lhs, node);
                    return rvalue(gz, ri, result, node);
                },
            }
        },
        .address_of => {
            const result = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);
            return rvalue(gz, ri, result, node);
        },
        .optional_type => {
            const operand = try typeExpr(gz, scope, node_datas[node].lhs);
            const result = try gz.addUnNode(.optional_type, operand, node);
            return rvalue(gz, ri, result, node);
        },
        .unwrap_optional => switch (ri.rl) {
            .ref => {
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
            switch (ri.rl) {
                .ref => return orelseCatchExpr(
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
            .ref => return orelseCatchExpr(
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

    const body_result = try expr(&suspend_scope, &suspend_scope.base, .{ .rl = .none }, body_node);
    if (!gz.refIsNoReturn(body_result)) {
        _ = try suspend_scope.addBreak(.break_inline, suspend_inst, .void_value);
    }
    try suspend_scope.setBlockBody(suspend_inst);

    return indexToRef(suspend_inst);
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
    const operand = try expr(gz, scope, .{ .rl = .none }, rhs_node);
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
    const operand = try expr(gz, scope, .{ .rl = .none }, rhs_node);
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

            const param_name: u32 = if (param.name_token) |name_token| blk: {
                if (mem.eql(u8, "_", tree.tokenSlice(name_token)))
                    break :blk 0;

                break :blk try astgen.identAsString(name_token);
            } else 0;

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
                const param_type = try expr(&param_gz, scope, coerced_type_ri, param_type_node);
                const param_inst_expected = @intCast(u32, astgen.instructions.len + 1);
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

    const align_ref: Zir.Inst.Ref = if (fn_proto.ast.align_expr == 0) .none else inst: {
        break :inst try expr(&block_scope, scope, align_ri, fn_proto.ast.align_expr);
    };

    if (fn_proto.ast.addrspace_expr != 0) {
        return astgen.failNode(fn_proto.ast.addrspace_expr, "addrspace not allowed on function prototypes", .{});
    }

    if (fn_proto.ast.section_expr != 0) {
        return astgen.failNode(fn_proto.ast.section_expr, "linksection not allowed on function prototypes", .{});
    }

    const cc: Zir.Inst.Ref = if (fn_proto.ast.callconv_expr != 0)
        try expr(
            &block_scope,
            scope,
            .{ .rl = .{ .ty = .calling_convention_type } },
            fn_proto.ast.callconv_expr,
        )
    else
        Zir.Inst.Ref.none;

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    const is_inferred_error = token_tags[maybe_bang] == .bang;
    if (is_inferred_error) {
        return astgen.failTok(maybe_bang, "function prototype may not have inferred error set", .{});
    }
    const ret_ty = try expr(&block_scope, scope, coerced_type_ri, fn_proto.ast.return_type);

    const result = try block_scope.addFunc(.{
        .src_node = fn_proto.ast.proto_node,

        .cc_ref = cc,
        .cc_gz = null,
        .align_ref = align_ref,
        .align_gz = null,
        .ret_ref = ret_ty,
        .ret_gz = null,
        .section_ref = .none,
        .section_gz = null,
        .addrspace_ref = .none,
        .addrspace_gz = null,

        .param_block = block_inst,
        .body_gz = null,
        .lib_name = 0,
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

    return rvalue(gz, ri, indexToRef(block_inst), fn_proto.ast.proto_node);
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

    const types: struct {
        array: Zir.Inst.Ref,
        elem: Zir.Inst.Ref,
    } = inst: {
        if (array_init.ast.type_expr == 0) break :inst .{
            .array = .none,
            .elem = .none,
        };

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
                    break :inst .{
                        .array = array_type_inst,
                        .elem = elem_type,
                    };
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
                    break :inst .{
                        .array = array_type_inst,
                        .elem = elem_type,
                    };
                }
            }
        }
        const array_type_inst = try typeExpr(gz, scope, array_init.ast.type_expr);
        _ = try gz.addPlNode(.validate_array_init_ty, node, Zir.Inst.ArrayInit{
            .ty = array_type_inst,
            .init_count = @intCast(u32, array_init.ast.elements.len),
        });
        break :inst .{
            .array = array_type_inst,
            .elem = .none,
        };
    };

    switch (ri.rl) {
        .discard => {
            // TODO elements should still be coerced if type is provided
            for (array_init.ast.elements) |elem_init| {
                _ = try expr(gz, scope, .{ .rl = .discard }, elem_init);
            }
            return Zir.Inst.Ref.void_value;
        },
        .ref => {
            const tag: Zir.Inst.Tag = if (types.array != .none) .array_init_ref else .array_init_anon_ref;
            return arrayInitExprInner(gz, scope, node, array_init.ast.elements, types.array, types.elem, tag);
        },
        .none => {
            const tag: Zir.Inst.Tag = if (types.array != .none) .array_init else .array_init_anon;
            return arrayInitExprInner(gz, scope, node, array_init.ast.elements, types.array, types.elem, tag);
        },
        .ty, .coerced_ty => {
            const tag: Zir.Inst.Tag = if (types.array != .none) .array_init else .array_init_anon;
            const result = try arrayInitExprInner(gz, scope, node, array_init.ast.elements, types.array, types.elem, tag);
            return rvalue(gz, ri, result, node);
        },
        .ptr => |ptr_res| {
            return arrayInitExprRlPtr(gz, scope, ri, node, ptr_res.inst, array_init.ast.elements, types.array);
        },
        .inferred_ptr => |ptr_inst| {
            if (types.array == .none) {
                // We treat this case differently so that we don't get a crash when
                // analyzing array_base_ptr against an alloc_inferred_mut.
                // See corresponding logic in structInitExpr.
                const result = try arrayInitExprRlNone(gz, scope, node, array_init.ast.elements, .array_init_anon);
                return rvalue(gz, ri, result, node);
            } else {
                return arrayInitExprRlPtr(gz, scope, ri, node, ptr_inst, array_init.ast.elements, types.array);
            }
        },
        .block_ptr => |block_gz| {
            // This condition is here for the same reason as the above condition in `inferred_ptr`.
            // See corresponding logic in structInitExpr.
            if (types.array == .none and astgen.isInferred(block_gz.rl_ptr)) {
                const result = try arrayInitExprRlNone(gz, scope, node, array_init.ast.elements, .array_init_anon);
                return rvalue(gz, ri, result, node);
            }
            return arrayInitExprRlPtr(gz, scope, ri, node, block_gz.rl_ptr, array_init.ast.elements, types.array);
        },
    }
}

fn arrayInitExprRlNone(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    elements: []const Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const payload_index = try addExtra(astgen, Zir.Inst.MultiOp{
        .operands_len = @intCast(u32, elements.len),
    });
    var extra_index = try reserveExtra(astgen, elements.len);

    for (elements) |elem_init| {
        const elem_ref = try expr(gz, scope, .{ .rl = .none }, elem_init);
        astgen.extra.items[extra_index] = @enumToInt(elem_ref);
        extra_index += 1;
    }
    return try gz.addPlNodePayloadIndex(tag, node, payload_index);
}

fn arrayInitExprInner(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    elements: []const Ast.Node.Index,
    array_ty_inst: Zir.Inst.Ref,
    elem_ty: Zir.Inst.Ref,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const len = elements.len + @boolToInt(array_ty_inst != .none);
    const payload_index = try addExtra(astgen, Zir.Inst.MultiOp{
        .operands_len = @intCast(u32, len),
    });
    var extra_index = try reserveExtra(astgen, len);
    if (array_ty_inst != .none) {
        astgen.extra.items[extra_index] = @enumToInt(array_ty_inst);
        extra_index += 1;
    }

    for (elements, 0..) |elem_init, i| {
        const ri = if (elem_ty != .none)
            ResultInfo{ .rl = .{ .coerced_ty = elem_ty } }
        else if (array_ty_inst != .none and nodeMayNeedMemoryLocation(astgen.tree, elem_init, true)) ri: {
            const ty_expr = try gz.add(.{
                .tag = .elem_type_index,
                .data = .{ .bin = .{
                    .lhs = array_ty_inst,
                    .rhs = @intToEnum(Zir.Inst.Ref, i),
                } },
            });
            break :ri ResultInfo{ .rl = .{ .coerced_ty = ty_expr } };
        } else ResultInfo{ .rl = .{ .none = {} } };

        const elem_ref = try expr(gz, scope, ri, elem_init);
        astgen.extra.items[extra_index] = @enumToInt(elem_ref);
        extra_index += 1;
    }

    return try gz.addPlNodePayloadIndex(tag, node, payload_index);
}

fn arrayInitExprRlPtr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    result_ptr: Zir.Inst.Ref,
    elements: []const Ast.Node.Index,
    array_ty: Zir.Inst.Ref,
) InnerError!Zir.Inst.Ref {
    if (array_ty == .none) {
        const base_ptr = try gz.addUnNode(.array_base_ptr, result_ptr, node);
        return arrayInitExprRlPtrInner(gz, scope, node, base_ptr, elements);
    }

    var as_scope = try gz.makeCoercionScope(scope, array_ty, result_ptr, node);
    defer as_scope.unstack();

    const result = try arrayInitExprRlPtrInner(&as_scope, scope, node, as_scope.rl_ptr, elements);
    return as_scope.finishCoercion(gz, ri, node, result, array_ty);
}

fn arrayInitExprRlPtrInner(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    result_ptr: Zir.Inst.Ref,
    elements: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const payload_index = try addExtra(astgen, Zir.Inst.Block{
        .body_len = @intCast(u32, elements.len),
    });
    var extra_index = try reserveExtra(astgen, elements.len);

    for (elements, 0..) |elem_init, i| {
        const elem_ptr = try gz.addPlNode(.elem_ptr_imm, elem_init, Zir.Inst.ElemPtrImm{
            .ptr = result_ptr,
            .index = @intCast(u32, i),
        });
        astgen.extra.items[extra_index] = refToIndex(elem_ptr).?;
        extra_index += 1;
        _ = try expr(gz, scope, .{ .rl = .{ .ptr = .{ .inst = elem_ptr } } }, elem_init);
    }

    _ = try gz.addPlNodePayloadIndex(.validate_array_init, node, payload_index);
    return .void_value;
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
            return rvalue(gz, ri, .empty_struct, node);
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

    switch (ri.rl) {
        .discard => {
            if (struct_init.ast.type_expr != 0) {
                const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
                _ = try gz.addUnNode(.validate_struct_init_ty, ty_inst, node);
                _ = try structInitExprRlTy(gz, scope, node, struct_init, ty_inst, .struct_init);
            } else {
                _ = try structInitExprRlNone(gz, scope, node, struct_init, .none, .struct_init_anon);
            }
            return Zir.Inst.Ref.void_value;
        },
        .ref => {
            if (struct_init.ast.type_expr != 0) {
                const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
                _ = try gz.addUnNode(.validate_struct_init_ty, ty_inst, node);
                return structInitExprRlTy(gz, scope, node, struct_init, ty_inst, .struct_init_ref);
            } else {
                return structInitExprRlNone(gz, scope, node, struct_init, .none, .struct_init_anon_ref);
            }
        },
        .none => {
            if (struct_init.ast.type_expr != 0) {
                const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
                _ = try gz.addUnNode(.validate_struct_init_ty, ty_inst, node);
                return structInitExprRlTy(gz, scope, node, struct_init, ty_inst, .struct_init);
            } else {
                return structInitExprRlNone(gz, scope, node, struct_init, .none, .struct_init_anon);
            }
        },
        .ty, .coerced_ty => |ty_inst| {
            if (struct_init.ast.type_expr == 0) {
                const result = try structInitExprRlNone(gz, scope, node, struct_init, ty_inst, .struct_init_anon);
                return rvalue(gz, ri, result, node);
            }
            const inner_ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
            _ = try gz.addUnNode(.validate_struct_init_ty, inner_ty_inst, node);
            const result = try structInitExprRlTy(gz, scope, node, struct_init, inner_ty_inst, .struct_init);
            return rvalue(gz, ri, result, node);
        },
        .ptr => |ptr_res| return structInitExprRlPtr(gz, scope, ri, node, struct_init, ptr_res.inst),
        .inferred_ptr => |ptr_inst| {
            if (struct_init.ast.type_expr == 0) {
                // We treat this case differently so that we don't get a crash when
                // analyzing field_base_ptr against an alloc_inferred_mut.
                // See corresponding logic in arrayInitExpr.
                const result = try structInitExprRlNone(gz, scope, node, struct_init, .none, .struct_init_anon);
                return rvalue(gz, ri, result, node);
            } else {
                return structInitExprRlPtr(gz, scope, ri, node, struct_init, ptr_inst);
            }
        },
        .block_ptr => |block_gz| {
            // This condition is here for the same reason as the above condition in `inferred_ptr`.
            // See corresponding logic in arrayInitExpr.
            if (struct_init.ast.type_expr == 0 and astgen.isInferred(block_gz.rl_ptr)) {
                const result = try structInitExprRlNone(gz, scope, node, struct_init, .none, .struct_init_anon);
                return rvalue(gz, ri, result, node);
            }

            return structInitExprRlPtr(gz, scope, ri, node, struct_init, block_gz.rl_ptr);
        },
    }
}

fn structInitExprRlNone(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    ty_inst: Zir.Inst.Ref,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const payload_index = try addExtra(astgen, Zir.Inst.StructInitAnon{
        .fields_len = @intCast(u32, struct_init.ast.fields.len),
    });
    const field_size = @typeInfo(Zir.Inst.StructInitAnon.Item).Struct.fields.len;
    var extra_index: usize = try reserveExtra(astgen, struct_init.ast.fields.len * field_size);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        const sub_ri: ResultInfo = if (ty_inst != .none)
            ResultInfo{ .rl = .{ .ty = try gz.addPlNode(.field_type, field_init, Zir.Inst.FieldType{
                .container_type = ty_inst,
                .name_start = str_index,
            }) } }
        else
            .{ .rl = .none };
        setExtra(astgen, extra_index, Zir.Inst.StructInitAnon.Item{
            .field_name = str_index,
            .init = try expr(gz, scope, sub_ri, field_init),
        });
        extra_index += field_size;
    }

    return try gz.addPlNodePayloadIndex(tag, node, payload_index);
}

fn structInitExprRlPtr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    result_ptr: Zir.Inst.Ref,
) InnerError!Zir.Inst.Ref {
    if (struct_init.ast.type_expr == 0) {
        const base_ptr = try gz.addUnNode(.field_base_ptr, result_ptr, node);
        return structInitExprRlPtrInner(gz, scope, node, struct_init, base_ptr);
    }
    const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
    _ = try gz.addUnNode(.validate_struct_init_ty, ty_inst, node);

    var as_scope = try gz.makeCoercionScope(scope, ty_inst, result_ptr, node);
    defer as_scope.unstack();

    const result = try structInitExprRlPtrInner(&as_scope, scope, node, struct_init, as_scope.rl_ptr);
    return as_scope.finishCoercion(gz, ri, node, result, ty_inst);
}

fn structInitExprRlPtrInner(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    result_ptr: Zir.Inst.Ref,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const payload_index = try addExtra(astgen, Zir.Inst.Block{
        .body_len = @intCast(u32, struct_init.ast.fields.len),
    });
    var extra_index = try reserveExtra(astgen, struct_init.ast.fields.len);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        const field_ptr = try gz.addPlNode(.field_ptr_init, field_init, Zir.Inst.Field{
            .lhs = result_ptr,
            .field_name_start = str_index,
        });
        astgen.extra.items[extra_index] = refToIndex(field_ptr).?;
        extra_index += 1;
        _ = try expr(gz, scope, .{ .rl = .{ .ptr = .{ .inst = field_ptr } } }, field_init);
    }

    _ = try gz.addPlNodePayloadIndex(.validate_struct_init, node, payload_index);
    return Zir.Inst.Ref.void_value;
}

fn structInitExprRlTy(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    ty_inst: Zir.Inst.Ref,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const payload_index = try addExtra(astgen, Zir.Inst.StructInit{
        .fields_len = @intCast(u32, struct_init.ast.fields.len),
    });
    const field_size = @typeInfo(Zir.Inst.StructInit.Item).Struct.fields.len;
    var extra_index: usize = try reserveExtra(astgen, struct_init.ast.fields.len * field_size);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        const field_ty_inst = try gz.addPlNode(.field_type, field_init, Zir.Inst.FieldType{
            .container_type = ty_inst,
            .name_start = str_index,
        });
        setExtra(astgen, extra_index, Zir.Inst.StructInit.Item{
            .field_type = refToIndex(field_ty_inst).?,
            .init = try expr(gz, scope, .{ .rl = .{ .ty = field_ty_inst } }, field_init),
        });
        extra_index += field_size;
    }

    return try gz.addPlNodePayloadIndex(tag, node, payload_index);
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

                        // Careful! We can't pass in the real result location here, since it may
                        // refer to runtime memory. A runtime-to-comptime boundary has to remove
                        // result location information, compute the result, and copy it to the true
                        // result location at runtime. We do this below as well.
                        const block_ref = try labeledBlockExpr(gz, scope, .{ .rl = .none }, node, stmt_slice, true);
                        return rvalue(gz, ri, block_ref, node);
                    },
                    .block, .block_semicolon => {
                        const stmts = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
                        // Replace result location and copy back later - see above.
                        const block_ref = try labeledBlockExpr(gz, scope, .{ .rl = .none }, node, stmts, true);
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
    const block_result = try expr(&block_scope, scope, .{ .rl = .none }, node);
    if (!gz.refIsNoReturn(block_result)) {
        _ = try block_scope.addBreak(.@"break", block_inst, block_result);
    }
    try block_scope.setBlockBody(block_inst);
    try gz.instructions.append(gz.astgen.gpa, block_inst);

    return rvalue(gz, ri, indexToRef(block_inst), node);
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
                .inferred_ptr => |ptr| try gz.addUnNode(.load, ptr, node),
                .block_ptr => |block_scope| if (block_scope.rvalue_rl_count != block_scope.break_count) b: {
                    // The result location may have been used by this expression, in which case
                    // the operand is not the result and we need to load the rl ptr.
                    switch (gz.astgen.instructions.items(.tag)[Zir.refToIndex(block_scope.rl_ptr).?]) {
                        .alloc_inferred, .alloc_inferred_mut => {
                            // This is a terrible workaround for Sema's inability to load from a .alloc_inferred ptr
                            // before its type has been resolved. The operand we use here instead is not guaranteed
                            // to be valid, and when it's not, we will pop error traces prematurely.
                            //
                            // TODO: Update this to do a proper load from the rl_ptr, once Sema can support it.
                            break :b result;
                        },
                        else => break :b try gz.addUnNode(.load, block_scope.rl_ptr, node),
                    }
                } else result,
                else => result,
            },
            else => .none, // always restore/pop
        },
    };
    _ = try gz.addRestoreErrRetIndex(bt, .{ .if_non_error = op });
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
                    } else if (block_gz.break_block != 0) {
                        break :blk block_gz.break_block;
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

                block_gz.break_count += 1;
                if (rhs == 0) {
                    _ = try rvalue(parent_gz, block_gz.break_result_info, .void_value, node);

                    try genDefers(parent_gz, scope, parent_scope, .normal_only);

                    // As our last action before the break, "pop" the error trace if needed
                    if (!block_gz.is_comptime)
                        _ = try parent_gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always);

                    _ = try parent_gz.addBreak(break_tag, block_inst, .void_value);
                    return Zir.Inst.Ref.unreachable_value;
                }

                const operand = try reachableExpr(parent_gz, parent_scope, block_gz.break_result_info, rhs, node);
                const search_index = @intCast(Zir.Inst.Index, astgen.instructions.len);

                try genDefers(parent_gz, scope, parent_scope, .normal_only);

                // As our last action before the break, "pop" the error trace if needed
                if (!block_gz.is_comptime)
                    try restoreErrRetIndex(parent_gz, .{ .block = block_inst }, block_gz.break_result_info, rhs, operand);

                switch (block_gz.break_result_info.rl) {
                    .block_ptr => {
                        const br = try parent_gz.addBreakWithSrcNode(break_tag, block_inst, operand, rhs);
                        try block_gz.labeled_breaks.append(astgen.gpa, .{ .br = br, .search = search_index });
                    },
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
            .namespace, .enum_namespace => break,
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

                const break_tag: Zir.Inst.Tag = if (gen_zir.is_inline)
                    .break_inline
                else
                    .@"break";
                if (break_tag == .break_inline) {
                    _ = try parent_gz.addUnNode(.check_comptime_control_flow, Zir.indexToRef(continue_block), node);
                }

                // As our last action before the continue, "pop" the error trace if needed
                if (!gen_zir.is_comptime)
                    _ = try parent_gz.addRestoreErrRetIndex(.{ .block = continue_block }, .always);

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
            .namespace, .enum_namespace => break,
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

fn blockExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

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
            _ = try gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always);
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
            .namespace, .enum_namespace => break,
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
    const tracy = trace(@src());
    defer tracy.end();

    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    const label_token = lbrace - 2;
    assert(token_tags[label_token] == .identifier);

    try astgen.checkLabelRedefinition(parent_scope, label_token);

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
    block_scope.setBreakResultInfo(ri);
    if (force_comptime) block_scope.is_comptime = true;
    defer block_scope.unstack();
    defer block_scope.labeled_breaks.deinit(astgen.gpa);

    try blockExprStmts(&block_scope, &block_scope.base, statements);
    if (!block_scope.endsWithNoReturn()) {
        // As our last action before the return, "pop" the error trace if needed
        _ = try gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always);
        _ = try block_scope.addBreak(.@"break", block_inst, .void_value);
    }

    if (!block_scope.label.?.used) {
        try astgen.appendErrorTok(label_token, "unused block label", .{});
    }

    const zir_datas = gz.astgen.instructions.items(.data);
    const zir_tags = gz.astgen.instructions.items(.tag);
    const strat = ri.rl.strategy(&block_scope);
    switch (strat.tag) {
        .break_void => {
            // The code took advantage of the result location as a pointer.
            // Turn the break instruction operands into void.
            for (block_scope.labeled_breaks.items) |br| {
                zir_datas[br.br].@"break".operand = .void_value;
            }
            try block_scope.setBlockBody(block_inst);

            return indexToRef(block_inst);
        },
        .break_operand => {
            // All break operands are values that did not use the result location pointer
            // (except for a single .store_to_block_ptr inst which we re-write here).
            // The break instructions need to have their operands coerced if the
            // block's result location is a `ty`. In this case we overwrite the
            // `store_to_block_ptr` instruction with an `as` instruction and repurpose
            // it as the break operand.
            // This corresponds to similar code in `setCondBrPayloadElideBlockStorePtr`.
            if (block_scope.rl_ty_inst != .none) {
                for (block_scope.labeled_breaks.items) |br| {
                    // We expect the `store_to_block_ptr` to be created between 1-3 instructions
                    // prior to the break.
                    var search_index = br.search -| 3;
                    while (search_index < br.search) : (search_index += 1) {
                        if (zir_tags[search_index] == .store_to_block_ptr and
                            zir_datas[search_index].bin.lhs == block_scope.rl_ptr)
                        {
                            zir_tags[search_index] = .as;
                            zir_datas[search_index].bin = .{
                                .lhs = block_scope.rl_ty_inst,
                                .rhs = zir_datas[br.br].@"break".operand,
                            };
                            zir_datas[br.br].@"break".operand = indexToRef(search_index);
                            break;
                        }
                    } else unreachable;
                }
            }
            try block_scope.setBlockBody(block_inst);
            const block_ref = indexToRef(block_inst);
            switch (ri.rl) {
                .ref => return block_ref,
                else => return rvalue(gz, ri, block_ref, block_node),
            }
        },
    }
}

fn blockExprStmts(gz: *GenZir, parent_scope: *Scope, statements: []const Ast.Node.Index) !void {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);

    if (statements.len == 0) return;

    try gz.addDbgBlockBegin();

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

    try gz.addDbgBlockEnd();

    try genDefers(gz, parent_scope, scope, .normal_only);
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
    const elide_check = if (refToIndex(maybe_unused_result)) |inst| b: {
        // Note that this array becomes invalid after appending more items to it
        // in the above while loop.
        const zir_tags = gz.astgen.instructions.items(.tag);
        switch (zir_tags[inst]) {
            // For some instructions, modify the zir data
            // so we can avoid a separate ensure_result_used instruction.
            .call => {
                const extra_index = gz.astgen.instructions.items(.data)[inst].pl_node.payload_index;
                const slot = &gz.astgen.extra.items[extra_index];
                var flags = @bitCast(Zir.Inst.Call.Flags, slot.*);
                flags.ensure_result_used = true;
                slot.* = @bitCast(u32, flags);
                break :b true;
            },
            .builtin_call => {
                const extra_index = gz.astgen.instructions.items(.data)[inst].pl_node.payload_index;
                const slot = &gz.astgen.extra.items[extra_index];
                var flags = @bitCast(Zir.Inst.BuiltinCall.Flags, slot.*);
                flags.ensure_result_used = true;
                slot.* = @bitCast(u32, flags);
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
            .elem_type_index,
            .vector_type,
            .indexable_ptr_len,
            .anyframe_type,
            .as,
            .as_node,
            .as_shift_operand,
            .bit_and,
            .bitcast,
            .bit_or,
            .block,
            .block_comptime,
            .block_inline,
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
            .coerce_result_ptr,
            .decl_ref,
            .decl_val,
            .load,
            .div,
            .elem_ptr,
            .elem_val,
            .elem_ptr_node,
            .elem_ptr_imm,
            .elem_val_node,
            .field_ptr,
            .field_ptr_init,
            .field_val,
            .field_call_bind,
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
            .switch_cond,
            .switch_cond_ref,
            .switch_capture,
            .switch_capture_ref,
            .switch_capture_multi,
            .switch_capture_multi_ref,
            .switch_capture_tag,
            .struct_init_empty,
            .struct_init,
            .struct_init_ref,
            .struct_init_anon,
            .struct_init_anon_ref,
            .array_init,
            .array_init_anon,
            .array_init_ref,
            .array_init_anon_ref,
            .union_init,
            .field_type,
            .field_type_ref,
            .error_set_decl,
            .error_set_decl_anon,
            .error_set_decl_func,
            .int_to_enum,
            .enum_to_int,
            .type_info,
            .size_of,
            .bit_size_of,
            .typeof_log2_int_type,
            .ptr_to_int,
            .align_of,
            .bool_to_int,
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
            .fabs,
            .floor,
            .ceil,
            .trunc,
            .round,
            .tag_name,
            .type_name,
            .frame_type,
            .frame_size,
            .float_to_int,
            .int_to_float,
            .int_to_ptr,
            .float_cast,
            .int_cast,
            .ptr_cast,
            .truncate,
            .align_cast,
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
            .field_parent_ptr,
            .max,
            .min,
            .c_import,
            .@"resume",
            .@"await",
            .ret_err_value_code,
            .closure_get,
            .array_base_ptr,
            .field_base_ptr,
            .ret_ptr,
            .ret_type,
            .for_len,
            .@"try",
            .try_ptr,
            => break :b false,

            .extended => switch (gz.astgen.instructions.items(.data)[inst].extended.opcode) {
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
            .dbg_block_begin,
            .dbg_block_end,
            .ensure_result_used,
            .ensure_result_non_error,
            .ensure_err_union_payload_void,
            .@"export",
            .export_value,
            .set_eval_branch_quota,
            .atomic_store,
            .store,
            .store_node,
            .store_to_block_ptr,
            .store_to_inferred_ptr,
            .resolve_inferred_alloc,
            .validate_struct_init,
            .validate_array_init,
            .set_runtime_safety,
            .closure_capture,
            .memcpy,
            .memset,
            .validate_array_init_ty,
            .validate_struct_init_ty,
            .validate_deref,
            .save_err_ret_index,
            .restore_err_ret_index,
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

                const have_err_payload = defer_scope.remapped_err_code != 0;
                need_err_code = need_err_code or have_err_payload;
            },
            .namespace, .enum_namespace => unreachable,
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
                        if (defer_scope.remapped_err_code == 0) {
                            try gz.addDefer(defer_scope.index, defer_scope.len);
                        } else {
                            try gz.instructions.ensureUnusedCapacity(gpa, 1);
                            try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

                            const payload_index = try gz.astgen.addExtra(Zir.Inst.DeferErrCode{
                                .remapped_err_code = defer_scope.remapped_err_code,
                                .index = defer_scope.index,
                                .len = defer_scope.len,
                            });
                            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
                            gz.astgen.instructions.appendAssumeCapacity(.{
                                .tag = .defer_err_code,
                                .data = .{ .defer_err_code = .{
                                    .err_code = err_code,
                                    .payload_index = payload_index,
                                } },
                            });
                            gz.instructions.appendAssumeCapacity(new_index);
                        }
                    },
                    .normal_only => continue,
                }
            },
            .namespace, .enum_namespace => unreachable,
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
                } else if (s.used != 0 and s.discarded != 0) {
                    try astgen.appendErrorTokNotes(s.discarded, "pointless discard of {s}", .{@tagName(s.id_cat)}, &[_]u32{
                        try gz.astgen.errNoteTok(s.used, "used here", .{}),
                    });
                }
                scope = s.parent;
            },
            .defer_normal, .defer_error => scope = scope.cast(Scope.Defer).?.parent,
            .namespace, .enum_namespace => unreachable,
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
    var remapped_err_code: Zir.Inst.Index = 0;
    const have_err_code = scope_tag == .defer_error and payload_token != 0;
    const sub_scope = if (!have_err_code) &defer_gen.base else blk: {
        try gz.addDbgBlockBegin();
        const ident_name = try gz.astgen.identAsString(payload_token);
        remapped_err_code = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        try gz.astgen.instructions.append(gz.astgen.gpa, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .errdefer_err_code,
                .small = undefined,
                .operand = undefined,
            } },
        });
        const remapped_err_code_ref = Zir.indexToRef(remapped_err_code);
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
    if (have_err_code) try gz.addDbgBlockEnd();
    _ = try defer_gen.addBreak(.break_inline, 0, .void_value);

    const body = defer_gen.instructionsSlice();
    const body_len = gz.astgen.countBodyLenAfterFixups(body);

    const index = @intCast(u32, gz.astgen.extra.items.len);
    try gz.astgen.extra.ensureUnusedCapacity(gz.astgen.gpa, body_len);
    gz.astgen.appendBodyWithFixups(body);

    const defer_scope = try block_arena.create(Scope.Defer);

    defer_scope.* = .{
        .base = .{ .tag = scope_tag },
        .parent = scope,
        .index = index,
        .len = body_len,
        .remapped_err_code = remapped_err_code,
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
        try expr(gz, scope, align_ri, var_decl.ast.align_node)
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
                !nodeMayNeedMemoryLocation(tree, var_decl.ast.init_node, type_node != 0))
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

            // Detect whether the initialization expression actually uses the
            // result location pointer.
            var init_scope = gz.makeSubBlock(scope);
            // we may add more instructions to gz before stacking init_scope
            init_scope.instructions_top = GenZir.unstacked_top;
            init_scope.anon_name_strategy = .dbg_var;
            defer init_scope.unstack();

            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            var opt_type_inst: Zir.Inst.Ref = .none;
            if (type_node != 0) {
                const type_inst = try typeExpr(gz, &init_scope.base, type_node);
                opt_type_inst = type_inst;
                if (align_inst == .none) {
                    init_scope.instructions_top = gz.instructions.items.len;
                    init_scope.rl_ptr = try init_scope.addUnNode(.alloc, type_inst, node);
                } else {
                    init_scope.rl_ptr = try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = type_inst,
                        .align_inst = align_inst,
                        .is_const = true,
                        .is_comptime = is_comptime,
                    });
                    init_scope.instructions_top = gz.instructions.items.len;
                }
                init_scope.rl_ty_inst = type_inst;
            } else {
                const alloc = if (align_inst == .none) alloc: {
                    init_scope.instructions_top = gz.instructions.items.len;
                    const tag: Zir.Inst.Tag = if (is_comptime)
                        .alloc_inferred_comptime
                    else
                        .alloc_inferred;
                    break :alloc try init_scope.addNode(tag, node);
                } else alloc: {
                    const ref = try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = .none,
                        .align_inst = align_inst,
                        .is_const = true,
                        .is_comptime = is_comptime,
                    });
                    init_scope.instructions_top = gz.instructions.items.len;
                    break :alloc ref;
                };
                resolve_inferred_alloc = alloc;
                init_scope.rl_ptr = alloc;
                init_scope.rl_ty_inst = .none;
            }
            const init_result_info: ResultInfo = .{ .rl = .{ .block_ptr = &init_scope }, .ctx = .const_init };
            const init_inst = try reachableExpr(&init_scope, &init_scope.base, init_result_info, var_decl.ast.init_node, node);

            // The const init expression may have modified the error return trace, so signal
            // to Sema that it should save the new index for restoring later.
            if (nodeMayAppendToErrorTrace(tree, var_decl.ast.init_node))
                _ = try init_scope.addSaveErrRetIndex(.{ .if_of_error_type = init_inst });

            const zir_tags = astgen.instructions.items(.tag);
            const zir_datas = astgen.instructions.items(.data);

            if (align_inst == .none and init_scope.rvalue_rl_count == 1) {
                // Result location pointer not used. We don't need an alloc for this
                // const local, and type inference becomes trivial.
                // Implicitly move the init_scope instructions into the parent scope,
                // then elide the alloc instruction and the store_to_block_ptr instruction.
                var src = init_scope.instructions_top;
                var dst = src;
                init_scope.instructions_top = GenZir.unstacked_top;
                while (src < gz.instructions.items.len) : (src += 1) {
                    const src_inst = gz.instructions.items[src];
                    if (indexToRef(src_inst) == init_scope.rl_ptr) continue;
                    if (zir_tags[src_inst] == .store_to_block_ptr) {
                        if (zir_datas[src_inst].bin.lhs == init_scope.rl_ptr) continue;
                    }
                    gz.instructions.items[dst] = src_inst;
                    dst += 1;
                }
                gz.instructions.items.len = dst;

                // In case the result location did not do the coercion
                // for us so we must do it here.
                const coerced_init = if (opt_type_inst != .none)
                    try gz.addBin(.as, opt_type_inst, init_inst)
                else
                    init_inst;

                try gz.addDbgVar(.dbg_var_val, ident_name, coerced_init);

                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = gz,
                    .name = ident_name,
                    .inst = coerced_init,
                    .token_src = name_token,
                    .id_cat = .@"local constant",
                };
                return &sub_scope.base;
            }
            // The initialization expression took advantage of the result location
            // of the const local. In this case we will create an alloc and a LocalPtr for it.
            // Implicitly move the init_scope instructions into the parent scope, then swap
            // store_to_block_ptr for store_to_inferred_ptr.

            var src = init_scope.instructions_top;
            init_scope.instructions_top = GenZir.unstacked_top;
            while (src < gz.instructions.items.len) : (src += 1) {
                const src_inst = gz.instructions.items[src];
                if (zir_tags[src_inst] == .store_to_block_ptr) {
                    if (zir_datas[src_inst].bin.lhs == init_scope.rl_ptr) {
                        if (type_node != 0) {
                            zir_tags[src_inst] = .store;
                        } else {
                            zir_tags[src_inst] = .store_to_inferred_ptr;
                        }
                    }
                }
            }
            if (resolve_inferred_alloc != .none) {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
            }
            const const_ptr = try gz.addUnNode(.make_ptr_const, init_scope.rl_ptr, node);

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
            const old_rl_ty_inst = gz.rl_ty_inst;
            defer gz.rl_ty_inst = old_rl_ty_inst;

            const is_comptime = var_decl.comptime_token != null or gz.is_comptime;
            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            const var_data: struct {
                result_info: ResultInfo,
                alloc: Zir.Inst.Ref,
            } = if (var_decl.ast.type_node != 0) a: {
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
                gz.rl_ty_inst = type_inst;
                break :a .{ .alloc = alloc, .result_info = .{ .rl = .{ .ptr = .{ .inst = alloc } } } };
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
                gz.rl_ty_inst = .none;
                resolve_inferred_alloc = alloc;
                break :a .{ .alloc = alloc, .result_info = .{ .rl = .{ .inferred_ptr = alloc } } };
            };
            const prev_anon_name_strategy = gz.anon_name_strategy;
            gz.anon_name_strategy = .dbg_var;
            _ = try reachableExprComptime(gz, scope, var_data.result_info, var_decl.ast.init_node, node, is_comptime);
            gz.anon_name_strategy = prev_anon_name_strategy;
            if (resolve_inferred_alloc != .none) {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
            }

            try gz.addDbgVar(.dbg_var_ptr, ident_name, var_data.alloc);

            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = gz,
                .name = ident_name,
                .ptr = var_data.alloc,
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

    if (gz.instructions.items.len > 0) {
        const last = gz.instructions.items[gz.instructions.items.len - 1];
        const zir_tags = astgen.instructions.items(.tag);
        if (zir_tags[last] == .dbg_stmt) {
            const zir_datas = astgen.instructions.items(.data);
            zir_datas[last].dbg_stmt = .{
                .line = line,
                .column = column,
            };
            return;
        }
    }

    _ = try gz.add(.{ .tag = .dbg_stmt, .data = .{
        .dbg_stmt = .{
            .line = line,
            .column = column,
        },
    } });
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
    _ = try gz.addBin(.store, lhs_ptr, result);
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
    _ = try gz.addBin(.store, lhs_ptr, result);
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
    _ = try gz.addBin(.store, lhs_ptr, result);
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

        addrspace_ref = try expr(gz, scope, .{ .rl = .{ .ty = .address_space_type } }, ptr_info.ast.addrspace_node);
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
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(sentinel_ref));
    }
    if (align_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(align_ref));
    }
    if (addrspace_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(addrspace_ref));
    }
    if (bit_start_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(bit_start_ref));
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(bit_end_ref));
    }

    const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
    const result = indexToRef(new_index);
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
    decls_start: u32,
    decls_end: u32,
    field_bits_start: u32,
    fields_start: u32,
    fields_end: u32,
    decl_index: u32 = 0,
    field_index: u32 = 0,

    const Self = @This();
    /// struct, union, enum, and opaque decls all use same 4 bits per decl
    const bits_per_decl = 4;
    const decls_per_u32 = 32 / bits_per_decl;
    /// struct, union, enum, and opaque decls all have maximum size of 11 u32 slots
    /// (4 for src_hash + line + name + value + doc_comment + align + link_section + address_space )
    const max_decl_size = 11;

    fn init(gpa: Allocator, payload: *ArrayListUnmanaged(u32), decl_count: u32, field_count: u32, comptime bits_per_field: u32, comptime max_field_size: u32) Allocator.Error!Self {
        const payload_top = @intCast(u32, payload.items.len);
        const decls_start = payload_top + (decl_count + decls_per_u32 - 1) / decls_per_u32;
        const field_bits_start = decls_start + decl_count * max_decl_size;
        const fields_start = field_bits_start + if (bits_per_field > 0) blk: {
            const fields_per_u32 = 32 / bits_per_field;
            break :blk (field_count + fields_per_u32 - 1) / fields_per_u32;
        } else 0;
        const payload_end = fields_start + field_count * max_field_size;
        try payload.resize(gpa, payload_end);
        return Self{
            .payload = payload,
            .payload_top = payload_top,
            .decls_start = decls_start,
            .field_bits_start = field_bits_start,
            .fields_start = fields_start,
            .decls_end = decls_start,
            .fields_end = fields_start,
        };
    }

    fn nextDecl(self: *Self, is_pub: bool, is_export: bool, has_align: bool, has_section_or_addrspace: bool) void {
        const index = self.payload_top + self.decl_index / decls_per_u32;
        assert(index < self.decls_start);
        const bit_bag: u32 = if (self.decl_index % decls_per_u32 == 0) 0 else self.payload.items[index];
        self.payload.items[index] = (bit_bag >> bits_per_decl) |
            (@as(u32, @boolToInt(is_pub)) << 28) |
            (@as(u32, @boolToInt(is_export)) << 29) |
            (@as(u32, @boolToInt(has_align)) << 30) |
            (@as(u32, @boolToInt(has_section_or_addrspace)) << 31);
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
            bit_bag |= @as(u32, @boolToInt(bits[i])) << (32 - bits_per_field + i);
        }
        self.payload.items[index] = bit_bag;
        self.field_index += 1;
    }

    fn appendToDecl(self: *Self, data: u32) void {
        assert(self.decls_end < self.field_bits_start);
        self.payload.items[self.decls_end] = data;
        self.decls_end += 1;
    }

    fn appendToDeclSlice(self: *Self, data: []const u32) void {
        assert(self.decls_end + data.len <= self.field_bits_start);
        @memcpy(self.payload.items[self.decls_end..][0..data.len], data);
        self.decls_end += @intCast(u32, data.len);
    }

    fn appendToField(self: *Self, data: u32) void {
        assert(self.fields_end < self.payload.items.len);
        self.payload.items[self.fields_end] = data;
        self.fields_end += 1;
    }

    fn finishBits(self: *Self, comptime bits_per_field: u32) void {
        const empty_decl_slots = decls_per_u32 - (self.decl_index % decls_per_u32);
        if (self.decl_index > 0 and empty_decl_slots < decls_per_u32) {
            const index = self.payload_top + self.decl_index / decls_per_u32;
            self.payload.items[index] >>= @intCast(u5, empty_decl_slots * bits_per_decl);
        }
        if (bits_per_field > 0) {
            const fields_per_u32 = 32 / bits_per_field;
            const empty_field_slots = fields_per_u32 - (self.field_index % fields_per_u32);
            if (self.field_index > 0 and empty_field_slots < fields_per_u32) {
                const index = self.field_bits_start + self.field_index / fields_per_u32;
                self.payload.items[index] >>= @intCast(u5, empty_field_slots * bits_per_field);
            }
        }
    }

    fn declsSlice(self: *Self) []u32 {
        return self.payload.items[self.payload_top..self.decls_end];
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
    const fn_name_str_index = try astgen.identAsString(fn_name_token);

    // We insert this at the beginning so that its instruction index marks the
    // start of the top level declaration.
    const block_inst = try gz.makeBlockInst(.block_inline, fn_proto.ast.proto_node);
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

    // align, linksection, and addrspace is passed in the func instruction in this case.
    wip_members.nextDecl(is_pub, is_export, false, false);

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

            const param_name: u32 = if (param.name_token) |name_token| blk: {
                const name_bytes = tree.tokenSlice(name_token);
                if (mem.eql(u8, "_", name_bytes))
                    break :blk 0;

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
            } else 0;

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
                const param_type = try expr(&param_gz, params_scope, coerced_type_ri, param_type_node);
                const param_inst_expected = @intCast(u32, astgen.instructions.len + 1);
                _ = try param_gz.addBreakWithSrcNode(.break_inline, param_inst_expected, param_type, param_type_node);

                const main_tokens = tree.nodes.items(.main_token);
                const name_token = param.name_token orelse main_tokens[param_type_node];
                const tag: Zir.Inst.Tag = if (is_comptime) .param_comptime else .param;
                const param_inst = try decl_gz.addParam(&param_gz, tag, name_token, param_name, param.first_doc_comment);
                assert(param_inst_expected == param_inst);
                break :param indexToRef(param_inst);
            };

            if (param_name == 0 or is_extern) continue;

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

    const lib_name: u32 = if (fn_proto.lib_name) |lib_name_token| blk: {
        const lib_name_str = try astgen.strLitAsString(lib_name_token);
        const lib_name_slice = astgen.string_bytes.items[lib_name_str.index..][0..lib_name_str.len];
        if (mem.indexOfScalar(u8, lib_name_slice, 0) != null) {
            return astgen.failTok(lib_name_token, "library name cannot contain null bytes", .{});
        } else if (lib_name_str.len == 0) {
            return astgen.failTok(lib_name_token, "library name cannot be empty", .{});
        }
        break :blk lib_name_str.index;
    } else 0;

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
        _ = try align_gz.addBreak(.break_inline, 0, inst);
        break :inst inst;
    };

    var addrspace_gz = decl_gz.makeSubBlock(params_scope);
    defer addrspace_gz.unstack();
    const addrspace_ref: Zir.Inst.Ref = if (fn_proto.ast.addrspace_expr == 0) .none else inst: {
        const inst = try expr(&decl_gz, params_scope, .{ .rl = .{ .coerced_ty = .address_space_type } }, fn_proto.ast.addrspace_expr);
        if (addrspace_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try addrspace_gz.addBreak(.break_inline, 0, inst);
        break :inst inst;
    };

    var section_gz = decl_gz.makeSubBlock(params_scope);
    defer section_gz.unstack();
    const section_ref: Zir.Inst.Ref = if (fn_proto.ast.section_expr == 0) .none else inst: {
        const inst = try expr(&decl_gz, params_scope, .{ .rl = .{ .coerced_ty = .const_slice_u8_type } }, fn_proto.ast.section_expr);
        if (section_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try section_gz.addBreak(.break_inline, 0, inst);
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
            _ = try cc_gz.addBreak(.break_inline, 0, inst);
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
        const inst = try expr(&ret_gz, params_scope, coerced_type_ri, fn_proto.ast.return_type);
        if (ret_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try ret_gz.addBreak(.break_inline, 0, inst);
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
            .param_block = block_inst,
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
        astgen.fn_block = &fn_gz;
        defer astgen.fn_block = prev_fn_block;

        const prev_var_args = astgen.fn_var_args;
        astgen.fn_var_args = is_var_args;
        defer astgen.fn_var_args = prev_var_args;

        astgen.advanceSourceCursorToNode(body_node);
        const lbrace_line = astgen.source_line - decl_gz.decl_line;
        const lbrace_column = astgen.source_column;

        _ = try expr(&fn_gz, params_scope, .{ .rl = .none }, body_node);
        try checkUsed(gz, &fn_gz.base, params_scope);

        if (!fn_gz.endsWithNoReturn()) {
            // As our last action before the return, "pop" the error trace if needed
            _ = try gz.addRestoreErrRetIndex(.ret, .always);

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
            .param_block = block_inst,
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
    _ = try decl_gz.addBreak(.break_inline, block_inst, func_inst);
    try decl_gz.setBlockBody(block_inst);

    {
        const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));
        const casted = @bitCast([4]u32, contents_hash);
        wip_members.appendToDeclSlice(&casted);
    }
    {
        const line_delta = decl_gz.decl_line - gz.decl_line;
        wip_members.appendToDecl(line_delta);
    }
    wip_members.appendToDecl(fn_name_str_index);
    wip_members.appendToDecl(block_inst);
    wip_members.appendToDecl(doc_comment_index);
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
    const block_inst = try gz.makeBlockInst(.block_inline, node);

    const name_token = var_decl.ast.mut_token + 1;
    const name_str_index = try astgen.identAsString(name_token);
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
    const align_inst: Zir.Inst.Ref = if (var_decl.ast.align_node == 0) .none else inst: {
        break :inst try expr(&block_scope, &block_scope.base, align_ri, var_decl.ast.align_node);
    };
    const addrspace_inst: Zir.Inst.Ref = if (var_decl.ast.addrspace_node == 0) .none else inst: {
        break :inst try expr(&block_scope, &block_scope.base, .{ .rl = .{ .ty = .address_space_type } }, var_decl.ast.addrspace_node);
    };
    const section_inst: Zir.Inst.Ref = if (var_decl.ast.section_node == 0) .none else inst: {
        break :inst try comptimeExpr(&block_scope, &block_scope.base, .{ .rl = .{ .ty = .const_slice_u8_type } }, var_decl.ast.section_node);
    };
    const has_section_or_addrspace = section_inst != .none or addrspace_inst != .none;
    wip_members.nextDecl(is_pub, is_export, align_inst != .none, has_section_or_addrspace);

    const is_threadlocal = if (var_decl.threadlocal_token) |tok| blk: {
        if (!is_mutable) {
            return astgen.failTok(tok, "threadlocal variable cannot be constant", .{});
        }
        break :blk true;
    } else false;

    const lib_name: u32 = if (var_decl.lib_name) |lib_name_token| blk: {
        const lib_name_str = try astgen.strLitAsString(lib_name_token);
        const lib_name_slice = astgen.string_bytes.items[lib_name_str.index..][0..lib_name_str.len];
        if (mem.indexOfScalar(u8, lib_name_slice, 0) != null) {
            return astgen.failTok(lib_name_token, "library name cannot contain null bytes", .{});
        } else if (lib_name_str.len == 0) {
            return astgen.failTok(lib_name_token, "library name cannot be empty", .{});
        }
        break :blk lib_name_str.index;
    } else 0;

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
                .{ .rl = .{ .ty = .type_type } },
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
                .lib_name = 0,
                .align_inst = .none, // passed via the decls data
                .init = init_inst,
                .is_extern = false,
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
            .is_threadlocal = is_threadlocal,
        });
        break :vi var_inst;
    } else {
        return astgen.failNode(node, "unable to infer variable type", .{});
    };
    // We do this at the end so that the instruction index marks the end
    // range of a top level declaration.
    _ = try block_scope.addBreakWithSrcNode(.break_inline, block_inst, var_inst, node);
    try block_scope.setBlockBody(block_inst);

    {
        const contents_hash = std.zig.hashSrc(tree.getNodeSource(node));
        const casted = @bitCast([4]u32, contents_hash);
        wip_members.appendToDeclSlice(&casted);
    }
    {
        const line_delta = block_scope.decl_line - gz.decl_line;
        wip_members.appendToDecl(line_delta);
    }
    wip_members.appendToDecl(name_str_index);
    wip_members.appendToDecl(block_inst);
    wip_members.appendToDecl(doc_comment_index); // doc_comment wip
    if (align_inst != .none) {
        wip_members.appendToDecl(@enumToInt(align_inst));
    }
    if (has_section_or_addrspace) {
        wip_members.appendToDecl(@enumToInt(section_inst));
        wip_members.appendToDecl(@enumToInt(addrspace_inst));
    }
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
    const block_inst = try gz.makeBlockInst(.block_inline, node);
    wip_members.nextDecl(false, false, false, false);
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

    const block_result = try expr(&decl_block, &decl_block.base, .{ .rl = .none }, body_node);
    if (decl_block.isEmpty() or !decl_block.refIsNoReturn(block_result)) {
        _ = try decl_block.addBreak(.break_inline, block_inst, .void_value);
    }
    try decl_block.setBlockBody(block_inst);

    {
        const contents_hash = std.zig.hashSrc(tree.getNodeSource(node));
        const casted = @bitCast([4]u32, contents_hash);
        wip_members.appendToDeclSlice(&casted);
    }
    {
        const line_delta = decl_block.decl_line - gz.decl_line;
        wip_members.appendToDecl(line_delta);
    }
    wip_members.appendToDecl(0);
    wip_members.appendToDecl(block_inst);
    wip_members.appendToDecl(0); // no doc comments on comptime decls
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
    const block_inst = try gz.makeBlockInst(.block_inline, node);
    wip_members.nextDecl(is_pub, true, false, false);
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
    _ = try decl_block.addBreak(.break_inline, block_inst, namespace_inst);
    try decl_block.setBlockBody(block_inst);

    {
        const contents_hash = std.zig.hashSrc(tree.getNodeSource(node));
        const casted = @bitCast([4]u32, contents_hash);
        wip_members.appendToDeclSlice(&casted);
    }
    {
        const line_delta = decl_block.decl_line - gz.decl_line;
        wip_members.appendToDecl(line_delta);
    }
    wip_members.appendToDecl(0);
    wip_members.appendToDecl(block_inst);
    wip_members.appendToDecl(0); // no doc comments on usingnamespace decls
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
    const block_inst = try gz.makeBlockInst(.block_inline, node);

    wip_members.nextDecl(false, false, false, false);
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
    const test_name_token_tag = token_tags[test_name_token];
    const is_decltest = test_name_token_tag == .identifier;
    const test_name: u32 = blk: {
        if (test_name_token_tag == .string_literal) {
            break :blk try astgen.testNameString(test_name_token);
        } else if (test_name_token_tag == .identifier) {
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
                .namespace, .enum_namespace => {
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

            break :blk name_str_index;
        }
        // String table index 1 has a special meaning here of test decl with no name.
        break :blk 1;
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

    const prev_fn_block = astgen.fn_block;
    astgen.fn_block = &fn_block;
    defer astgen.fn_block = prev_fn_block;

    astgen.advanceSourceCursorToNode(body_node);
    const lbrace_line = astgen.source_line - decl_block.decl_line;
    const lbrace_column = astgen.source_column;

    const block_result = try expr(&fn_block, &fn_block.base, .{ .rl = .none }, body_node);
    if (fn_block.isEmpty() or !fn_block.refIsNoReturn(block_result)) {

        // As our last action before the return, "pop" the error trace if needed
        _ = try gz.addRestoreErrRetIndex(.ret, .always);

        // Add implicit return at end of function.
        _ = try fn_block.addUnTok(.ret_implicit, .void_value, tree.lastToken(body_node));
    }

    const func_inst = try decl_block.addFunc(.{
        .src_node = node,

        .cc_ref = .none,
        .cc_gz = null,
        .align_ref = .none,
        .align_gz = null,
        .ret_ref = .void_type,
        .ret_gz = null,
        .section_ref = .none,
        .section_gz = null,
        .addrspace_ref = .none,
        .addrspace_gz = null,

        .lbrace_line = lbrace_line,
        .lbrace_column = lbrace_column,
        .param_block = block_inst,
        .body_gz = &fn_block,
        .lib_name = 0,
        .is_var_args = false,
        .is_inferred_error = true,
        .is_test = true,
        .is_extern = false,
        .is_noinline = false,
        .noalias_bits = 0,
    });

    _ = try decl_block.addBreak(.break_inline, block_inst, func_inst);
    try decl_block.setBlockBody(block_inst);

    {
        const contents_hash = std.zig.hashSrc(tree.getNodeSource(node));
        const casted = @bitCast([4]u32, contents_hash);
        wip_members.appendToDeclSlice(&casted);
    }
    {
        const line_delta = decl_block.decl_line - gz.decl_line;
        wip_members.appendToDecl(line_delta);
    }
    if (is_decltest)
        wip_members.appendToDecl(2) // 2 here means that it is a decltest, look at doc comment for name
    else
        wip_members.appendToDecl(test_name);
    wip_members.appendToDecl(block_inst);
    if (is_decltest)
        wip_members.appendToDecl(test_name) // the doc comment on a decltest represents it's name
    else
        wip_members.appendToDecl(0); // no doc comments on test decls
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
            .fields_len = 0,
            .decls_len = 0,
            .backing_int_ref = .none,
            .backing_int_body_len = 0,
            .known_non_opv = false,
            .known_comptime_only = false,
            .is_tuple = false,
        });
        return indexToRef(decl_inst);
    }

    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;

    var namespace: Scope.Namespace = .{
        .parent = scope,
        .node = node,
        .inst = decl_inst,
        .declaring_gz = gz,
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
            if (layout != .Packed) {
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
    const field_count = @intCast(u32, container_decl.ast.members.len - decl_count);

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

    var is_tuple = false;
    const node_tags = tree.nodes.items(.tag);
    for (container_decl.ast.members) |member_node| {
        const container_field = tree.fullContainerField(member_node) orelse continue;
        is_tuple = container_field.ast.tuple_like;
        if (is_tuple) break;
    }
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

    var known_non_opv = false;
    var known_comptime_only = false;
    for (container_decl.ast.members) |member_node| {
        var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
            .decl => continue,
            .field => |field| field,
        };

        if (!is_tuple) {
            member.convertToNonTupleLike(astgen.tree.nodes);
            assert(!member.ast.tuple_like);

            const field_name = try astgen.identAsString(member.ast.main_token);
            wip_members.appendToField(field_name);
        } else if (!member.ast.tuple_like) {
            return astgen.failTok(member.ast.main_token, "tuple field has a name", .{});
        }

        const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
        wip_members.appendToField(doc_comment_index);

        if (member.ast.type_expr == 0) {
            return astgen.failTok(member.ast.main_token, "struct field missing type", .{});
        }

        const field_type = try typeExpr(&block_scope, &namespace.base, member.ast.type_expr);
        const have_type_body = !block_scope.isEmpty();
        const have_align = member.ast.align_expr != 0;
        const have_value = member.ast.value_expr != 0;
        const is_comptime = member.comptime_token != null;

        if (is_comptime and layout == .Packed) {
            return astgen.failTok(member.comptime_token.?, "packed struct fields cannot be marked comptime", .{});
        } else if (is_comptime and layout == .Extern) {
            return astgen.failTok(member.comptime_token.?, "extern struct fields cannot be marked comptime", .{});
        }

        if (!is_comptime) {
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
            wip_members.appendToField(@intCast(u32, astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        } else {
            wip_members.appendToField(@enumToInt(field_type));
        }

        if (have_align) {
            if (layout == .Packed) {
                try astgen.appendErrorNode(member.ast.align_expr, "unable to override alignment of packed struct fields", .{});
            }
            const align_ref = try expr(&block_scope, &namespace.base, coerced_align_ri, member.ast.align_expr);
            if (!block_scope.endsWithNoReturn()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, align_ref);
            }
            const body = block_scope.instructionsSlice();
            const old_scratch_len = astgen.scratch.items.len;
            try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
            appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
            wip_members.appendToField(@intCast(u32, astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        }

        if (have_value) {
            const ri: ResultInfo = .{ .rl = if (field_type == .none) .none else .{ .coerced_ty = field_type } };

            const default_inst = try expr(&block_scope, &namespace.base, ri, member.ast.value_expr);
            if (!block_scope.endsWithNoReturn()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, default_inst);
            }
            const body = block_scope.instructionsSlice();
            const old_scratch_len = astgen.scratch.items.len;
            try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
            appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
            wip_members.appendToField(@intCast(u32, astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        } else if (member.comptime_token) |comptime_token| {
            return astgen.failTok(comptime_token, "comptime field without default initialization value", .{});
        }
    }

    try gz.setStruct(decl_inst, .{
        .src_node = node,
        .layout = layout,
        .fields_len = field_count,
        .decls_len = decl_count,
        .backing_int_ref = backing_int_ref,
        .backing_int_body_len = @intCast(u32, backing_int_body_len),
        .known_non_opv = known_non_opv,
        .known_comptime_only = known_comptime_only,
        .is_tuple = is_tuple,
    });

    wip_members.finishBits(bits_per_field);
    const decls_slice = wip_members.declsSlice();
    const fields_slice = wip_members.fieldsSlice();
    const bodies_slice = astgen.scratch.items[bodies_start..];
    try astgen.extra.ensureUnusedCapacity(gpa, backing_int_body_len +
        decls_slice.len + fields_slice.len + bodies_slice.len);
    astgen.extra.appendSliceAssumeCapacity(astgen.scratch.items[scratch_top..][0..backing_int_body_len]);
    astgen.extra.appendSliceAssumeCapacity(decls_slice);
    astgen.extra.appendSliceAssumeCapacity(fields_slice);
    astgen.extra.appendSliceAssumeCapacity(bodies_slice);

    block_scope.unstack();
    try gz.addNamespaceCaptures(&namespace);
    return indexToRef(decl_inst);
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
    const field_count = @intCast(u32, members.len - decl_count);

    if (layout != .Auto and (auto_enum_tok != null or arg_node != 0)) {
        const layout_str = if (layout == .Extern) "extern" else "packed";
        if (arg_node != 0) {
            return astgen.failNode(arg_node, "{s} union does not support enum tag type", .{layout_str});
        } else {
            return astgen.failTok(auto_enum_tok.?, "{s} union does not support enum tag type", .{layout_str});
        }
    }

    const arg_inst: Zir.Inst.Ref = if (arg_node != 0)
        try typeExpr(&block_scope, &namespace.base, arg_node)
    else
        .none;

    const bits_per_field = 4;
    const max_field_size = 5;
    var wip_members = try WipMembers.init(gpa, &astgen.scratch, decl_count, field_count, bits_per_field, max_field_size);
    defer wip_members.deinit();

    for (members) |member_node| {
        var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
            .decl => continue,
            .field => |field| field,
        };
        member.convertToNonTupleLike(astgen.tree.nodes);
        if (member.ast.tuple_like) {
            return astgen.failTok(member.ast.main_token, "union field missing name", .{});
        }
        if (member.comptime_token) |comptime_token| {
            return astgen.failTok(comptime_token, "union fields cannot be marked comptime", .{});
        }

        const field_name = try astgen.identAsString(member.ast.main_token);
        wip_members.appendToField(field_name);

        const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
        wip_members.appendToField(doc_comment_index);

        const have_type = member.ast.type_expr != 0;
        const have_align = member.ast.align_expr != 0;
        const have_value = member.ast.value_expr != 0;
        const unused = false;
        wip_members.nextField(bits_per_field, .{ have_type, have_align, have_value, unused });

        if (have_type) {
            const field_type = try typeExpr(&block_scope, &namespace.base, member.ast.type_expr);
            wip_members.appendToField(@enumToInt(field_type));
        } else if (arg_inst == .none and auto_enum_tok == null) {
            return astgen.failNode(member_node, "union field missing type", .{});
        }
        if (have_align) {
            const align_inst = try expr(&block_scope, &block_scope.base, .{ .rl = .{ .ty = .u32_type } }, member.ast.align_expr);
            wip_members.appendToField(@enumToInt(align_inst));
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
            wip_members.appendToField(@enumToInt(tag_value));
        }
    }

    if (!block_scope.isEmpty()) {
        _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
    }

    const body = block_scope.instructionsSlice();
    const body_len = astgen.countBodyLenAfterFixups(body);

    try gz.setUnion(decl_inst, .{
        .src_node = node,
        .layout = layout,
        .tag_type = arg_inst,
        .body_len = body_len,
        .fields_len = field_count,
        .decls_len = decl_count,
        .auto_enum_tag = auto_enum_tok != null,
    });

    wip_members.finishBits(bits_per_field);
    const decls_slice = wip_members.declsSlice();
    const fields_slice = wip_members.fieldsSlice();
    try astgen.extra.ensureUnusedCapacity(gpa, decls_slice.len + body_len + fields_slice.len);
    astgen.extra.appendSliceAssumeCapacity(decls_slice);
    astgen.appendBodyWithFixups(body);
    astgen.extra.appendSliceAssumeCapacity(fields_slice);

    block_scope.unstack();
    try gz.addNamespaceCaptures(&namespace);
    return indexToRef(decl_inst);
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
            const layout = if (container_decl.layout_token) |t| switch (token_tags[t]) {
                .keyword_packed => std.builtin.Type.ContainerLayout.Packed,
                .keyword_extern => std.builtin.Type.ContainerLayout.Extern,
                else => unreachable,
            } else std.builtin.Type.ContainerLayout.Auto;

            const result = try structDeclInner(gz, scope, node, container_decl, layout, container_decl.ast.arg);
            return rvalue(gz, ri, result, node);
        },
        .keyword_union => {
            const layout = if (container_decl.layout_token) |t| switch (token_tags[t]) {
                .keyword_packed => std.builtin.Type.ContainerLayout.Packed,
                .keyword_extern => std.builtin.Type.ContainerLayout.Extern,
                else => unreachable,
            } else std.builtin.Type.ContainerLayout.Auto;

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
            namespace.base.tag = .enum_namespace;

            const arg_inst: Zir.Inst.Ref = if (container_decl.ast.arg != 0)
                try comptimeExpr(&block_scope, &namespace.base, .{ .rl = .{ .ty = .type_type } }, container_decl.ast.arg)
            else
                .none;

            const bits_per_field = 1;
            const max_field_size = 3;
            var wip_members = try WipMembers.init(gpa, &astgen.scratch, @intCast(u32, counts.decls), @intCast(u32, counts.total_fields), bits_per_field, max_field_size);
            defer wip_members.deinit();

            for (container_decl.ast.members) |member_node| {
                if (member_node == counts.nonexhaustive_node)
                    continue;
                namespace.base.tag = .namespace;
                var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
                    .decl => continue,
                    .field => |field| field,
                };
                member.convertToNonTupleLike(astgen.tree.nodes);
                assert(member.comptime_token == null);
                assert(member.ast.type_expr == 0);
                assert(member.ast.align_expr == 0);

                const field_name = try astgen.identAsString(member.ast.main_token);
                wip_members.appendToField(field_name);

                const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
                wip_members.appendToField(doc_comment_index);

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
                    namespace.base.tag = .enum_namespace;
                    const tag_value_inst = try expr(&block_scope, &namespace.base, .{ .rl = .{ .ty = arg_inst } }, member.ast.value_expr);
                    wip_members.appendToField(@enumToInt(tag_value_inst));
                }
            }

            if (!block_scope.isEmpty()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
            }

            const body = block_scope.instructionsSlice();
            const body_len = astgen.countBodyLenAfterFixups(body);

            try gz.setEnum(decl_inst, .{
                .src_node = node,
                .nonexhaustive = nonexhaustive,
                .tag_type = arg_inst,
                .body_len = body_len,
                .fields_len = @intCast(u32, counts.total_fields),
                .decls_len = @intCast(u32, counts.decls),
            });

            wip_members.finishBits(bits_per_field);
            const decls_slice = wip_members.declsSlice();
            const fields_slice = wip_members.fieldsSlice();
            try astgen.extra.ensureUnusedCapacity(gpa, decls_slice.len + body_len + fields_slice.len);
            astgen.extra.appendSliceAssumeCapacity(decls_slice);
            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(fields_slice);

            block_scope.unstack();
            try gz.addNamespaceCaptures(&namespace);
            return rvalue(gz, ri, indexToRef(decl_inst), node);
        },
        .keyword_opaque => {
            assert(container_decl.ast.arg == 0);

            const decl_inst = try gz.reserveInstructionIndex();

            var namespace: Scope.Namespace = .{
                .parent = scope,
                .node = node,
                .inst = decl_inst,
                .declaring_gz = gz,
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
                .decls_len = decl_count,
            });

            wip_members.finishBits(0);
            const decls_slice = wip_members.declsSlice();
            try astgen.extra.ensureUnusedCapacity(gpa, decls_slice.len);
            astgen.extra.appendSliceAssumeCapacity(decls_slice);

            block_scope.unstack();
            try gz.addNamespaceCaptures(&namespace);
            return rvalue(gz, ri, indexToRef(decl_inst), node);
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
        var idents: std.AutoHashMapUnmanaged(u32, Ast.TokenIndex) = .{};
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
                    astgen.extra.appendAssumeCapacity(str_index);
                    const doc_comment_index = try astgen.docCommentAsString(tok_i);
                    astgen.extra.appendAssumeCapacity(doc_comment_index);
                    fields_len += 1;
                },
                .r_brace => break,
                else => unreachable,
            }
        }
    }

    setExtra(astgen, payload_index, Zir.Inst.ErrorSetDecl{
        .fields_len = @intCast(u32, fields_len),
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
        .ref => .{ .rl = .ref, .ctx = .error_handling_expr },
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
        .ref => Zir.Inst.Tag.err_union_code_ptr,
        else => Zir.Inst.Tag.err_union_code,
    };
    const err_code = try else_scope.addUnNode(err_tag, operand, node);
    try genDefers(&else_scope, &fn_block.base, scope, .{ .both = err_code });
    try emitDbgStmt(&else_scope, try_lc);
    _ = try else_scope.addUnNode(.ret_node, err_code, node);

    try else_scope.setTryBody(try_inst, operand);
    const result = indexToRef(try_inst);
    switch (ri.rl) {
        .ref => return result,
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

    const do_err_trace = astgen.fn_block != null and (cond_op == .is_non_err or cond_op == .is_non_err_ptr);

    var block_scope = parent_gz.makeSubBlock(scope);
    block_scope.setBreakResultInfo(ri);
    defer block_scope.unstack();

    const operand_ri: ResultInfo = switch (block_scope.break_result_info.rl) {
        .ref => .{ .rl = .ref, .ctx = if (do_err_trace) .error_handling_expr else .none },
        else => .{ .rl = .none, .ctx = if (do_err_trace) .error_handling_expr else .none },
    };
    block_scope.break_count += 1;
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
        .ref => unwrapped_payload,
        else => try rvalue(&then_scope, block_scope.break_result_info, unwrapped_payload, node),
    };

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

    const else_result = try expr(&else_scope, else_sub_scope, block_scope.break_result_info, rhs);
    if (!else_scope.endsWithNoReturn()) {
        block_scope.break_count += 1;

        // As our last action before the break, "pop" the error trace if needed
        if (do_err_trace)
            try restoreErrRetIndex(&else_scope, .{ .block = block }, block_scope.break_result_info, rhs, else_result);
    }
    try checkUsed(parent_gz, &else_scope.base, else_sub_scope);

    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    const result = try finishThenElseBlock(
        parent_gz,
        ri,
        node,
        &block_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        then_result,
        node,
        else_result,
        rhs,
        block,
        block,
        .@"break",
    );
    return result;
}

/// Supports `else_scope` stacked on `then_scope` stacked on `block_scope`. Unstacks `else_scope` then `then_scope`.
fn finishThenElseBlock(
    parent_gz: *GenZir,
    ri: ResultInfo,
    node: Ast.Node.Index,
    block_scope: *GenZir,
    then_scope: *GenZir,
    else_scope: *GenZir,
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_result: Zir.Inst.Ref,
    then_src_node: Ast.Node.Index,
    else_result: Zir.Inst.Ref,
    else_src_node: Ast.Node.Index,
    main_block: Zir.Inst.Index,
    then_break_block: Zir.Inst.Index,
    break_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    // We now have enough information to decide whether the result instruction should
    // be communicated via result location pointer or break instructions.
    const strat = ri.rl.strategy(block_scope);
    // else_scope may be stacked on then_scope, so check for no-return on then_scope manually
    const tags = parent_gz.astgen.instructions.items(.tag);
    const then_slice = then_scope.instructionsSliceUpto(else_scope);
    const then_no_return = then_slice.len > 0 and tags[then_slice[then_slice.len - 1]].isNoReturn();
    const else_no_return = else_scope.endsWithNoReturn();

    switch (strat.tag) {
        .break_void => {
            const then_break = if (!then_no_return) try then_scope.makeBreak(break_tag, then_break_block, .void_value) else 0;
            const else_break = if (!else_no_return) try else_scope.makeBreak(break_tag, main_block, .void_value) else 0;
            assert(!strat.elide_store_to_block_ptr_instructions);
            try setCondBrPayload(condbr, cond, then_scope, then_break, else_scope, else_break);
            return indexToRef(main_block);
        },
        .break_operand => {
            const then_break = if (!then_no_return) try then_scope.makeBreakWithSrcNode(break_tag, then_break_block, then_result, then_src_node) else 0;
            const else_break = if (else_result == .none)
                try else_scope.makeBreak(break_tag, main_block, .void_value)
            else if (!else_no_return)
                try else_scope.makeBreakWithSrcNode(break_tag, main_block, else_result, else_src_node)
            else
                0;

            if (strat.elide_store_to_block_ptr_instructions) {
                try setCondBrPayloadElideBlockStorePtr(condbr, cond, then_scope, then_break, else_scope, else_break, block_scope.rl_ptr);
            } else {
                try setCondBrPayload(condbr, cond, then_scope, then_break, else_scope, else_break);
            }
            const block_ref = indexToRef(main_block);
            switch (ri.rl) {
                .ref => return block_ref,
                else => return rvalue(parent_gz, ri, block_ref, node),
            }
        },
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
        .ref => return addFieldAccess(.field_ptr, gz, scope, .{ .rl = .ref }, node),
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
        .ref => {
            const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);

            const rhs = try expr(gz, scope, .{ .rl = .{ .ty = .usize_type } }, node_datas[node].rhs);
            try emitDbgStmt(gz, cursor);

            return gz.addPlNode(.elem_ptr_node, node, Zir.Inst.Bin{ .lhs = lhs, .rhs = rhs });
        },
        else => {
            const lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);

            const rhs = try expr(gz, scope, .{ .rl = .{ .ty = .usize_type } }, node_datas[node].rhs);
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

    const lhs = try expr(gz, scope, bool_ri, node_datas[node].lhs);
    const bool_br = try gz.addBoolBr(zir_tag, lhs);

    var rhs_scope = gz.makeSubBlock(scope);
    defer rhs_scope.unstack();
    const rhs = try expr(&rhs_scope, &rhs_scope.base, bool_ri, node_datas[node].rhs);
    if (!gz.refIsNoReturn(rhs)) {
        _ = try rhs_scope.addBreakWithSrcNode(.break_inline, bool_br, rhs, node_datas[node].rhs);
    }
    try rhs_scope.setBoolBrBody(bool_br);

    const block_ref = indexToRef(bool_br);
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

    var block_scope = parent_gz.makeSubBlock(scope);
    block_scope.setBreakResultInfo(ri);
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
            const cond = try expr(&block_scope, &block_scope.base, bool_ri, if_full.ast.cond_expr);
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

    try then_scope.addDbgBlockBegin();
    const then_node = if_full.ast.then_expr;
    const then_sub_scope = s: {
        if (if_full.error_token != null) {
            if (if_full.payload_token) |payload_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_payload_unsafe_ptr
                else
                    .err_union_payload_unsafe;
                const payload_inst = try then_scope.addUnNode(tag, cond.inst, then_node);
                const token_name_index = payload_token + @boolToInt(payload_is_ref);
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
                    .token_src = payload_token,
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

    const then_result = try expr(&then_scope, then_sub_scope, block_scope.break_result_info, then_node);
    if (!then_scope.endsWithNoReturn()) {
        block_scope.break_count += 1;
    }
    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);
    try then_scope.addDbgBlockEnd();
    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    var else_scope = parent_gz.makeSubBlock(scope);
    defer else_scope.unstack();

    // We know that the operand (almost certainly) modified the error return trace,
    // so signal to Sema that it should save the new index for restoring later.
    if (do_err_trace and nodeMayAppendToErrorTrace(tree, if_full.ast.cond_expr))
        _ = try else_scope.addSaveErrRetIndex(.always);

    const else_node = if_full.ast.else_expr;
    const else_info: struct {
        src: Ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        try else_scope.addDbgBlockBegin();
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
        const e = try expr(&else_scope, sub_scope, block_scope.break_result_info, else_node);
        if (!else_scope.endsWithNoReturn()) {
            block_scope.break_count += 1;

            // As our last action before the break, "pop" the error trace if needed
            if (do_err_trace)
                try restoreErrRetIndex(&else_scope, .{ .block = block }, block_scope.break_result_info, else_node, e);
        }
        try checkUsed(parent_gz, &else_scope.base, sub_scope);
        try else_scope.addDbgBlockEnd();
        break :blk .{
            .src = else_node,
            .result = e,
        };
    } else .{
        .src = then_node,
        .result = switch (ri.rl) {
            // Explicitly store void to ptr result loc if there is no else branch
            .ptr, .block_ptr => try rvalue(&else_scope, ri, .void_value, node),
            else => .none,
        },
    };

    const result = try finishThenElseBlock(
        parent_gz,
        ri,
        node,
        &block_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond.bool_bit,
        then_result,
        then_node,
        else_info.result,
        else_info.src,
        block,
        block,
        .@"break",
    );
    return result;
}

/// Supports `else_scope` stacked on `then_scope`. Unstacks `else_scope` then `then_scope`.
fn setCondBrPayload(
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_scope: *GenZir,
    then_break: Zir.Inst.Index,
    else_scope: *GenZir,
    else_break: Zir.Inst.Index,
) !void {
    defer then_scope.unstack();
    defer else_scope.unstack();
    const astgen = then_scope.astgen;
    const then_body = then_scope.instructionsSliceUpto(else_scope);
    const else_body = else_scope.instructionsSlice();
    const then_body_len = astgen.countBodyLenAfterFixups(then_body) + @boolToInt(then_break != 0);
    const else_body_len = astgen.countBodyLenAfterFixups(else_body) + @boolToInt(else_break != 0);
    try astgen.extra.ensureUnusedCapacity(
        astgen.gpa,
        @typeInfo(Zir.Inst.CondBr).Struct.fields.len + then_body_len + else_body_len,
    );

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[condbr].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.CondBr{
        .condition = cond,
        .then_body_len = then_body_len,
        .else_body_len = else_body_len,
    });
    astgen.appendBodyWithFixups(then_body);
    if (then_break != 0) astgen.extra.appendAssumeCapacity(then_break);
    astgen.appendBodyWithFixups(else_body);
    if (else_break != 0) astgen.extra.appendAssumeCapacity(else_break);
}

/// Supports `else_scope` stacked on `then_scope`. Unstacks `else_scope` then `then_scope`.
fn setCondBrPayloadElideBlockStorePtr(
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_scope: *GenZir,
    then_break: Zir.Inst.Index,
    else_scope: *GenZir,
    else_break: Zir.Inst.Index,
    block_ptr: Zir.Inst.Ref,
) !void {
    defer then_scope.unstack();
    defer else_scope.unstack();
    const astgen = then_scope.astgen;
    const then_body = then_scope.instructionsSliceUpto(else_scope);
    const else_body = else_scope.instructionsSlice();
    const has_then_break = then_break != 0;
    const has_else_break = else_break != 0;
    const then_body_len = astgen.countBodyLenAfterFixups(then_body) + @boolToInt(has_then_break);
    const else_body_len = astgen.countBodyLenAfterFixups(else_body) + @boolToInt(has_else_break);
    try astgen.extra.ensureUnusedCapacity(
        astgen.gpa,
        @typeInfo(Zir.Inst.CondBr).Struct.fields.len + then_body_len + else_body_len,
    );

    const zir_tags = astgen.instructions.items(.tag);
    const zir_datas = astgen.instructions.items(.data);

    const condbr_pl = astgen.addExtraAssumeCapacity(Zir.Inst.CondBr{
        .condition = cond,
        .then_body_len = then_body_len,
        .else_body_len = else_body_len,
    });
    zir_datas[condbr].pl_node.payload_index = condbr_pl;
    const then_body_len_index = condbr_pl + 1;
    const else_body_len_index = condbr_pl + 2;

    // The break instructions need to have their operands coerced if the
    // switch's result location is a `ty`. In this case we overwrite the
    // `store_to_block_ptr` instruction with an `as` instruction and repurpose
    // it as the break operand.
    // This corresponds to similar code in `labeledBlockExpr`.
    for (then_body) |src_inst| {
        if (zir_tags[src_inst] == .store_to_block_ptr and
            zir_datas[src_inst].bin.lhs == block_ptr)
        {
            if (then_scope.rl_ty_inst != .none and has_then_break) {
                zir_tags[src_inst] = .as;
                zir_datas[src_inst].bin = .{
                    .lhs = then_scope.rl_ty_inst,
                    .rhs = zir_datas[then_break].@"break".operand,
                };
                zir_datas[then_break].@"break".operand = indexToRef(src_inst);
            } else {
                astgen.extra.items[then_body_len_index] -= 1;
                continue;
            }
        }
        appendPossiblyRefdBodyInst(astgen, &astgen.extra, src_inst);
    }
    if (has_then_break) astgen.extra.appendAssumeCapacity(then_break);

    for (else_body) |src_inst| {
        if (zir_tags[src_inst] == .store_to_block_ptr and
            zir_datas[src_inst].bin.lhs == block_ptr)
        {
            if (else_scope.rl_ty_inst != .none and has_else_break) {
                zir_tags[src_inst] = .as;
                zir_datas[src_inst].bin = .{
                    .lhs = else_scope.rl_ty_inst,
                    .rhs = zir_datas[else_break].@"break".operand,
                };
                zir_datas[else_break].@"break".operand = indexToRef(src_inst);
            } else {
                astgen.extra.items[else_body_len_index] -= 1;
                continue;
            }
        }
        appendPossiblyRefdBodyInst(astgen, &astgen.extra, src_inst);
    }
    if (has_else_break) astgen.extra.appendAssumeCapacity(else_break);
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

    if (while_full.label_token) |label_token| {
        try astgen.checkLabelRedefinition(scope, label_token);
    }

    const is_inline = while_full.inline_token != null;
    const loop_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .loop;
    const loop_block = try parent_gz.makeBlockInst(loop_tag, node);
    try parent_gz.instructions.append(astgen.gpa, loop_block);

    var loop_scope = parent_gz.makeSubBlock(scope);
    loop_scope.is_inline = is_inline;
    loop_scope.setBreakResultInfo(ri);
    defer loop_scope.unstack();
    defer loop_scope.labeled_breaks.deinit(astgen.gpa);

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
            const err_union = try expr(&cond_scope, &cond_scope.base, cond_ri, while_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_err_ptr else .is_non_err;
            break :c .{
                .inst = err_union,
                .bool_bit = try cond_scope.addUnNode(tag, err_union, while_full.ast.cond_expr),
            };
        } else if (while_full.payload_token) |_| {
            const cond_ri: ResultInfo = .{ .rl = if (payload_is_ref) .ref else .none };
            const optional = try expr(&cond_scope, &cond_scope.base, cond_ri, while_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_null_ptr else .is_non_null;
            break :c .{
                .inst = optional,
                .bool_bit = try cond_scope.addUnNode(tag, optional, while_full.ast.cond_expr),
            };
        } else {
            const cond = try expr(&cond_scope, &cond_scope.base, bool_ri, while_full.ast.cond_expr);
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

    var dbg_var_name: ?u32 = null;
    var dbg_var_inst: Zir.Inst.Ref = undefined;
    var payload_inst: Zir.Inst.Index = 0;
    var payload_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = s: {
        if (while_full.error_token != null) {
            if (while_full.payload_token) |payload_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_payload_unsafe_ptr
                else
                    .err_union_payload_unsafe;
                // will add this instruction to then_scope.instructions below
                payload_inst = try then_scope.makeUnNode(tag, cond.inst, while_full.ast.cond_expr);
                const ident_token = if (payload_is_ref) payload_token + 1 else payload_token;
                const ident_bytes = tree.tokenSlice(ident_token);
                if (mem.eql(u8, "_", ident_bytes))
                    break :s &then_scope.base;
                const payload_name_loc = payload_token + @boolToInt(payload_is_ref);
                const ident_name = try astgen.identAsString(payload_name_loc);
                try astgen.detectLocalShadowing(&then_scope.base, ident_name, payload_name_loc, ident_bytes, .capture);
                payload_val_scope = .{
                    .parent = &then_scope.base,
                    .gen_zir = &then_scope,
                    .name = ident_name,
                    .inst = indexToRef(payload_inst),
                    .token_src = payload_token,
                    .id_cat = .capture,
                };
                dbg_var_name = ident_name;
                dbg_var_inst = indexToRef(payload_inst);
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
            payload_inst = try then_scope.makeUnNode(tag, cond.inst, while_full.ast.cond_expr);
            const ident_name = try astgen.identAsString(ident_token);
            const ident_bytes = tree.tokenSlice(ident_token);
            if (mem.eql(u8, "_", ident_bytes))
                break :s &then_scope.base;
            try astgen.detectLocalShadowing(&then_scope.base, ident_name, ident_token, ident_bytes, .capture);
            payload_val_scope = .{
                .parent = &then_scope.base,
                .gen_zir = &then_scope,
                .name = ident_name,
                .inst = indexToRef(payload_inst),
                .token_src = ident_token,
                .id_cat = .capture,
            };
            dbg_var_name = ident_name;
            dbg_var_inst = indexToRef(payload_inst);
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
    loop_scope.break_block = loop_block;
    loop_scope.continue_block = continue_block;
    if (while_full.label_token) |label_token| {
        loop_scope.label = @as(?GenZir.Label, GenZir.Label{
            .token = label_token,
            .block_inst = loop_block,
        });
    }

    // done adding instructions to loop_scope, can now stack then_scope
    then_scope.instructions_top = then_scope.instructions.items.len;

    try then_scope.addDbgBlockBegin();
    const then_node = while_full.ast.then_expr;
    if (payload_inst != 0) try then_scope.instructions.append(astgen.gpa, payload_inst);
    if (dbg_var_name) |name| try then_scope.addDbgVar(.dbg_var_val, name, dbg_var_inst);
    try then_scope.instructions.append(astgen.gpa, continue_block);
    // This code could be improved to avoid emitting the continue expr when there
    // are no jumps to it. This happens when the last statement of a while body is noreturn
    // and there are no `continue` statements.
    // Tracking issue: https://github.com/ziglang/zig/issues/9185
    if (while_full.ast.cont_expr != 0) {
        _ = try unusedResultExpr(&then_scope, then_sub_scope, while_full.ast.cont_expr);
    }
    try then_scope.addDbgBlockEnd();

    continue_scope.instructions_top = continue_scope.instructions.items.len;
    _ = try unusedResultExpr(&continue_scope, &continue_scope.base, then_node);
    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);
    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";
    if (!continue_scope.endsWithNoReturn()) {
        const break_inst = try continue_scope.makeBreak(break_tag, continue_block, .void_value);
        try then_scope.instructions.append(astgen.gpa, break_inst);
    }
    try continue_scope.setBlockBody(continue_block);

    var else_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer else_scope.unstack();

    const else_node = while_full.ast.else_expr;
    const else_info: struct {
        src: Ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        try else_scope.addDbgBlockBegin();
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
        loop_scope.continue_block = 0;
        loop_scope.break_block = 0;
        const else_result = try expr(&else_scope, sub_scope, loop_scope.break_result_info, else_node);
        if (is_statement) {
            _ = try addEnsureResult(&else_scope, else_result, else_node);
        }

        if (!else_scope.endsWithNoReturn()) {
            loop_scope.break_count += 1;
        }
        try checkUsed(parent_gz, &else_scope.base, sub_scope);
        try else_scope.addDbgBlockEnd();
        break :blk .{
            .src = else_node,
            .result = else_result,
        };
    } else .{
        .src = then_node,
        .result = .none,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            try astgen.appendErrorTok(some.token, "unused while loop label", .{});
        }
    }
    const result = try finishThenElseBlock(
        parent_gz,
        ri,
        node,
        &loop_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond.bool_bit,
        .void_value,
        then_node,
        else_info.result,
        else_info.src,
        loop_block,
        cond_block,
        break_tag,
    );
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

    const is_inline = for_full.inline_token != null;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const gpa = astgen.gpa;

    // TODO this can be deleted after zig 0.11.0 is released because it
    // will be caught in the parser.
    if (for_full.isOldSyntax(token_tags)) {
        return astgen.failTokNotes(
            for_full.payload_token + 2,
            "extra capture in for loop",
            .{},
            &[_]u32{
                try astgen.errNoteTok(
                    for_full.payload_token + 2,
                    "run 'zig fmt' to upgrade your code automatically",
                    .{},
                ),
            },
        );
    }

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
        _ = try parent_gz.addBin(.store, index_ptr, .zero_usize);
        break :blk index_ptr;
    };

    var any_len_checks = false;

    {
        var capture_token = for_full.payload_token;
        for (for_full.ast.inputs, 0..) |input, i_usize| {
            const i = @intCast(u32, i_usize);
            const capture_is_ref = token_tags[capture_token] == .asterisk;
            const ident_tok = capture_token + @boolToInt(capture_is_ref);
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
                const start_val = try expr(parent_gz, scope, .{ .rl = .none }, start_node);

                const end_node = node_data[input].rhs;
                const end_val = if (end_node != 0)
                    try expr(parent_gz, scope, .{ .rl = .none }, node_data[input].rhs)
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
                indexables[i] = if (start_is_zero) .none else start_val;
                lens[i] = range_len;
            } else {
                const indexable = try expr(parent_gz, scope, .{ .rl = .none }, input);

                any_len_checks = true;
                indexables[i] = indexable;
                lens[i] = indexable;
            }
        }
    }

    if (!any_len_checks) {
        return astgen.failNode(node, "unbounded for loop", .{});
    }

    // We use a dedicated ZIR instruction to assert the lengths to assist with
    // nicer error reporting as well as fewer ZIR bytes emitted.
    const len: Zir.Inst.Ref = len: {
        const lens_len = @intCast(u32, lens.len);
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
    loop_scope.setBreakResultInfo(ri);
    defer loop_scope.unstack();
    defer loop_scope.labeled_breaks.deinit(gpa);

    const index = try loop_scope.addUnNode(.load, index_ptr, node);

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
    // cond_block unstacked now, can add new instructions to loop_scope
    try loop_scope.instructions.append(gpa, cond_block);

    // Increment the index variable.
    const index_plus_one = try loop_scope.addPlNode(.add_unsafe, node, Zir.Inst.Bin{
        .lhs = index,
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

    var then_node = for_full.ast.then_expr;
    var then_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer then_scope.unstack();

    try then_scope.addDbgBlockBegin();

    const capture_scopes = try gpa.alloc(Scope.LocalVal, for_full.ast.inputs.len);
    defer gpa.free(capture_scopes);

    const then_sub_scope = blk: {
        var capture_token = for_full.payload_token;
        var capture_sub_scope: *Scope = &then_scope.base;
        for (for_full.ast.inputs, 0..) |input, i_usize| {
            const i = @intCast(u32, i_usize);
            const capture_is_ref = token_tags[capture_token] == .asterisk;
            const ident_tok = capture_token + @boolToInt(capture_is_ref);
            const capture_name = tree.tokenSlice(ident_tok);
            // Skip over the comma, and on to the next capture (or the ending pipe character).
            capture_token = ident_tok + 2;

            if (mem.eql(u8, capture_name, "_")) continue;

            const name_str_index = try astgen.identAsString(ident_tok);
            try astgen.detectLocalShadowing(capture_sub_scope, name_str_index, ident_tok, capture_name, .capture);

            const capture_inst = inst: {
                const is_counter = node_tags[input] == .for_range;

                if (indexables[i] == .none) {
                    // Special case: the main index can be used directly.
                    assert(is_counter);
                    assert(!capture_is_ref);
                    break :inst index;
                }

                // For counters, we add the index variable to the start value; for
                // indexables, we use it as an element index. This is so similar
                // that they can share the same code paths, branching only on the
                // ZIR tag.
                const switch_cond = (@as(u2, @boolToInt(capture_is_ref)) << 1) | @boolToInt(is_counter);
                const tag: Zir.Inst.Tag = switch (switch_cond) {
                    0b00 => .elem_val,
                    0b01 => .add,
                    0b10 => .elem_ptr,
                    0b11 => unreachable, // compile error emitted already
                };
                break :inst try then_scope.addPlNode(tag, input, Zir.Inst.Bin{
                    .lhs = indexables[i],
                    .rhs = index,
                });
            };

            capture_scopes[i] = .{
                .parent = capture_sub_scope,
                .gen_zir = &then_scope,
                .name = name_str_index,
                .inst = capture_inst,
                .token_src = ident_tok,
                .id_cat = .capture,
            };

            try then_scope.addDbgVar(.dbg_var_val, name_str_index, capture_inst);
            capture_sub_scope = &capture_scopes[i].base;
        }

        break :blk capture_sub_scope;
    };

    const then_result = try expr(&then_scope, then_sub_scope, .{ .rl = .none }, then_node);
    _ = try addEnsureResult(&then_scope, then_result, then_node);

    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);
    try then_scope.addDbgBlockEnd();

    var else_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer else_scope.unstack();

    const else_node = for_full.ast.else_expr;
    const else_info: struct {
        src: Ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        const sub_scope = &else_scope.base;
        // Remove the continue block and break block so that `continue` and `break`
        // control flow apply to outer loops; not this one.
        loop_scope.continue_block = 0;
        loop_scope.break_block = 0;
        const else_result = try expr(&else_scope, sub_scope, loop_scope.break_result_info, else_node);
        if (is_statement) {
            _ = try addEnsureResult(&else_scope, else_result, else_node);
        }

        if (!else_scope.endsWithNoReturn()) {
            loop_scope.break_count += 1;
        }
        break :blk .{
            .src = else_node,
            .result = else_result,
        };
    } else .{
        .src = then_node,
        .result = .none,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            try astgen.appendErrorTok(some.token, "unused for loop label", .{});
        }
    }
    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";
    const result = try finishThenElseBlock(
        parent_gz,
        ri,
        node,
        &loop_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        then_result,
        then_node,
        else_info.result,
        else_info.src,
        loop_block,
        cond_block,
        break_tag,
    );
    if (ri.rl.strategy(&loop_scope).tag == .break_void and loop_scope.break_count == 0) {
        _ = try rvalue(parent_gz, ri, .void_value, node);
    }
    if (is_statement) {
        _ = try parent_gz.addUnNode(.ensure_result_used, result, node);
    }
    return result;
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

    // We perform two passes over the AST. This first pass is to collect information
    // for the following variables, make note of the special prong AST node index,
    // and bail out with a compile error if there are multiple special prongs present.
    var any_payload_is_ref = false;
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
    const cond_tag: Zir.Inst.Tag = if (any_payload_is_ref) .switch_cond_ref else .switch_cond;
    const cond = try parent_gz.addUnNode(cond_tag, raw_operand, operand_node);
    // Sema expects a dbg_stmt immediately after switch_cond(_ref)
    try emitDbgStmt(parent_gz, operand_lc);
    // We need the type of the operand to use as the result location for all the prong items.
    const cond_ty_inst = try parent_gz.addUnNode(.typeof, cond, operand_node);
    const item_ri: ResultInfo = .{ .rl = .{ .ty = cond_ty_inst } };

    // This contains the data that goes into the `extra` array for the SwitchBlock/SwitchBlockMulti,
    // except the first cases_nodes.len slots are a table that indexes payloads later in the array, with
    // the special case index coming first, then scalar_case_len indexes, then multi_cases_len indexes
    const payloads = &astgen.scratch;
    const scratch_top = astgen.scratch.items.len;
    const case_table_start = scratch_top;
    const scalar_case_table = case_table_start + @boolToInt(special_prong != .none);
    const multi_case_table = scalar_case_table + scalar_cases_len;
    const case_table_end = multi_case_table + multi_cases_len;
    try astgen.scratch.resize(gpa, case_table_end);
    defer astgen.scratch.items.len = scratch_top;

    var block_scope = parent_gz.makeSubBlock(scope);
    // block_scope not used for collecting instructions
    block_scope.instructions_top = GenZir.unstacked_top;
    block_scope.setBreakResultInfo(ri);

    // This gets added to the parent block later, after the item expressions.
    const switch_block = try parent_gz.makeBlockInst(.switch_block, switch_node);

    // We re-use this same scope for all cases, including the special prong, if any.
    var case_scope = parent_gz.makeSubBlock(&block_scope.base);
    case_scope.instructions_top = GenZir.unstacked_top;

    // In this pass we generate all the item and prong expressions.
    var multi_case_index: u32 = 0;
    var scalar_case_index: u32 = 0;
    for (case_nodes) |case_node| {
        const case = tree.fullSwitchCase(case_node).?;

        const is_multi_case = case.ast.values.len > 1 or
            (case.ast.values.len == 1 and node_tags[case.ast.values[0]] == .switch_range);

        var dbg_var_name: ?u32 = null;
        var dbg_var_inst: Zir.Inst.Ref = undefined;
        var dbg_var_tag_name: ?u32 = null;
        var dbg_var_tag_inst: Zir.Inst.Ref = undefined;
        var capture_inst: Zir.Inst.Index = 0;
        var tag_inst: Zir.Inst.Index = 0;
        var capture_val_scope: Scope.LocalVal = undefined;
        var tag_scope: Scope.LocalVal = undefined;
        const sub_scope = blk: {
            const payload_token = case.payload_token orelse break :blk &case_scope.base;
            const ident = if (token_tags[payload_token] == .asterisk)
                payload_token + 1
            else
                payload_token;
            const is_ptr = ident != payload_token;
            const ident_slice = tree.tokenSlice(ident);
            var payload_sub_scope: *Scope = undefined;
            if (mem.eql(u8, ident_slice, "_")) {
                if (is_ptr) {
                    return astgen.failTok(payload_token, "pointer modifier invalid on discard", .{});
                }
                payload_sub_scope = &case_scope.base;
            } else {
                if (case_node == special_node) {
                    const capture_tag: Zir.Inst.Tag = if (is_ptr)
                        .switch_capture_ref
                    else
                        .switch_capture;
                    capture_inst = @intCast(Zir.Inst.Index, astgen.instructions.len);
                    try astgen.instructions.append(gpa, .{
                        .tag = capture_tag,
                        .data = .{
                            .switch_capture = .{
                                .switch_inst = switch_block,
                                // Max int communicates that this is the else/underscore prong.
                                .prong_index = std.math.maxInt(u32),
                            },
                        },
                    });
                } else {
                    const is_multi_case_bits: u2 = @boolToInt(is_multi_case);
                    const is_ptr_bits: u2 = @boolToInt(is_ptr);
                    const capture_tag: Zir.Inst.Tag = switch ((is_multi_case_bits << 1) | is_ptr_bits) {
                        0b00 => .switch_capture,
                        0b01 => .switch_capture_ref,
                        0b10 => .switch_capture_multi,
                        0b11 => .switch_capture_multi_ref,
                    };
                    const capture_index = if (is_multi_case) multi_case_index else scalar_case_index;
                    capture_inst = @intCast(Zir.Inst.Index, astgen.instructions.len);
                    try astgen.instructions.append(gpa, .{
                        .tag = capture_tag,
                        .data = .{ .switch_capture = .{
                            .switch_inst = switch_block,
                            .prong_index = capture_index,
                        } },
                    });
                }
                const capture_name = try astgen.identAsString(ident);
                try astgen.detectLocalShadowing(&case_scope.base, capture_name, ident, ident_slice, .capture);
                capture_val_scope = .{
                    .parent = &case_scope.base,
                    .gen_zir = &case_scope,
                    .name = capture_name,
                    .inst = indexToRef(capture_inst),
                    .token_src = payload_token,
                    .id_cat = .capture,
                };
                dbg_var_name = capture_name;
                dbg_var_inst = indexToRef(capture_inst);
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
            tag_inst = @intCast(Zir.Inst.Index, astgen.instructions.len);
            try astgen.instructions.append(gpa, .{
                .tag = .switch_capture_tag,
                .data = .{ .un_tok = .{
                    .operand = cond,
                    .src_tok = case_scope.tokenIndexToRelative(tag_token),
                } },
            });

            tag_scope = .{
                .parent = payload_sub_scope,
                .gen_zir = &case_scope,
                .name = tag_name,
                .inst = indexToRef(tag_inst),
                .token_src = tag_token,
                .id_cat = .@"switch tag capture",
            };
            dbg_var_tag_name = tag_name;
            dbg_var_tag_inst = indexToRef(tag_inst);
            break :blk &tag_scope.base;
        };

        const header_index = @intCast(u32, payloads.items.len);
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
                try payloads.append(gpa, @enumToInt(item_inst));
            }

            // ranges
            var ranges_len: u32 = 0;
            for (case.ast.values) |range| {
                if (node_tags[range] != .switch_range) continue;
                ranges_len += 1;

                const first = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].lhs);
                const last = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].rhs);
                try payloads.appendSlice(gpa, &[_]u32{
                    @enumToInt(first), @enumToInt(last),
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
            payloads.items[header_index] = @enumToInt(item_inst);
            break :blk header_index + 1;
        };

        {
            // temporarily stack case_scope on parent_gz
            case_scope.instructions_top = parent_gz.instructions.items.len;
            defer case_scope.unstack();

            if (capture_inst != 0) try case_scope.instructions.append(gpa, capture_inst);
            if (tag_inst != 0) try case_scope.instructions.append(gpa, tag_inst);
            try case_scope.addDbgBlockBegin();
            if (dbg_var_name) |some| {
                try case_scope.addDbgVar(.dbg_var_val, some, dbg_var_inst);
            }
            if (dbg_var_tag_name) |some| {
                try case_scope.addDbgVar(.dbg_var_val, some, dbg_var_tag_inst);
            }
            const target_expr_node = case.ast.target_expr;
            const case_result = try expr(&case_scope, sub_scope, block_scope.break_result_info, target_expr_node);
            try checkUsed(parent_gz, &case_scope.base, sub_scope);
            try case_scope.addDbgBlockEnd();
            if (!parent_gz.refIsNoReturn(case_result)) {
                block_scope.break_count += 1;
                _ = try case_scope.addBreakWithSrcNode(.@"break", switch_block, case_result, target_expr_node);
            }

            const case_slice = case_scope.instructionsSlice();
            const body_len = astgen.countBodyLenAfterFixups(case_slice);
            try payloads.ensureUnusedCapacity(gpa, body_len);
            const inline_bit = @as(u32, @boolToInt(case.inline_token != null)) << 31;
            payloads.items[body_len_index] = body_len | inline_bit;
            appendBodyWithFixupsArrayList(astgen, payloads, case_slice);
        }
    }
    // Now that the item expressions are generated we can add this.
    try parent_gz.instructions.append(gpa, switch_block);

    try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.SwitchBlock).Struct.fields.len +
        @boolToInt(multi_cases_len != 0) +
        payloads.items.len - case_table_end);

    const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.SwitchBlock{
        .operand = cond,
        .bits = Zir.Inst.SwitchBlock.Bits{
            .has_multi_cases = multi_cases_len != 0,
            .has_else = special_prong == .@"else",
            .has_under = special_prong == .under,
            .scalar_cases_len = @intCast(Zir.Inst.SwitchBlock.Bits.ScalarCasesLen, scalar_cases_len),
        },
    });

    if (multi_cases_len != 0) {
        astgen.extra.appendAssumeCapacity(multi_cases_len);
    }

    const zir_datas = astgen.instructions.items(.data);
    const zir_tags = astgen.instructions.items(.tag);

    zir_datas[switch_block].pl_node.payload_index = payload_index;

    const strat = ri.rl.strategy(&block_scope);
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

        const body_len = @truncate(u31, payloads.items[body_len_index]);
        end_index += body_len;

        switch (strat.tag) {
            .break_operand => blk: {
                // Switch expressions return `true` for `nodeMayNeedMemoryLocation` thus
                // `elide_store_to_block_ptr_instructions` will either be true,
                // or all prongs are noreturn.
                if (!strat.elide_store_to_block_ptr_instructions)
                    break :blk;

                // There will necessarily be a store_to_block_ptr for
                // all prongs, except for prongs that ended with a noreturn instruction.
                // Elide all the `store_to_block_ptr` instructions.

                // The break instructions need to have their operands coerced if the
                // switch's result location is a `ty`. In this case we overwrite the
                // `store_to_block_ptr` instruction with an `as` instruction and repurpose
                // it as the break operand.
                if (body_len < 2)
                    break :blk;

                var store_index = end_index - 2;
                while (true) : (store_index -= 1) switch (zir_tags[payloads.items[store_index]]) {
                    .dbg_block_end, .dbg_block_begin, .dbg_stmt, .dbg_var_val, .dbg_var_ptr => {},
                    else => break,
                };
                const store_inst = payloads.items[store_index];
                if (zir_tags[store_inst] != .store_to_block_ptr or
                    zir_datas[store_inst].bin.lhs != block_scope.rl_ptr)
                    break :blk;
                const break_inst = payloads.items[end_index - 1];
                if (block_scope.rl_ty_inst != .none) {
                    zir_tags[store_inst] = .as;
                    zir_datas[store_inst].bin = .{
                        .lhs = block_scope.rl_ty_inst,
                        .rhs = zir_datas[break_inst].@"break".operand,
                    };
                    zir_datas[break_inst].@"break".operand = indexToRef(store_inst);
                } else {
                    payloads.items[body_len_index] -= 1;
                    astgen.extra.appendSliceAssumeCapacity(payloads.items[start_index .. end_index - 2]);
                    astgen.extra.appendAssumeCapacity(break_inst);
                    continue;
                }
            },
            .break_void => {
                assert(!strat.elide_store_to_block_ptr_instructions);
                const last_inst = payloads.items[end_index - 1];
                if (zir_tags[last_inst] == .@"break") {
                    const inst_data = zir_datas[last_inst].@"break";
                    const block_inst = astgen.extra.items[inst_data.payload_index];
                    if (block_inst == switch_block) {
                        zir_datas[last_inst].@"break".operand = .void_value;
                    }
                }
            },
        }

        astgen.extra.appendSliceAssumeCapacity(payloads.items[start_index..end_index]);
    }

    const block_ref = indexToRef(switch_block);
    if (strat.tag == .break_operand and strat.elide_store_to_block_ptr_instructions and ri.rl != .ref)
        return rvalue(parent_gz, ri, block_ref, switch_node);
    return block_ref;
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
        _ = try gz.addRestoreErrRetIndex(.ret, .always);

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

    const ri: ResultInfo = if (nodeMayNeedMemoryLocation(tree, operand_node, true)) .{
        .rl = .{ .ptr = .{ .inst = try gz.addNode(.ret_ptr, node) } },
        .ctx = .@"return",
    } else .{
        .rl = .{ .ty = try gz.addNode(.ret_type, node) },
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
            _ = try gz.addRestoreErrRetIndex(.ret, .always);

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
                _ = try gz.addRestoreErrRetIndex(.ret, .{ .if_non_error = result });

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
            _ = try then_scope.addRestoreErrRetIndex(.ret, .always);

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

            try setCondBrPayload(condbr, is_non_err, &then_scope, 0, &else_scope, 0);

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
        x = try std.math.add(u16, x, @as(u16, digit));
    }

    return x;
}

fn identifier(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    ident: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

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
    const gpa = astgen.gpa;
    const name_str_index = try astgen.identAsString(ident_token);
    var s = scope;
    var found_already: ?Ast.Node.Index = null; // we have found a decl with the same name already
    var num_namespaces_out: u32 = 0;
    var capturing_namespace: ?*Scope.Namespace = null;
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

                const value_inst = try tunnelThroughClosure(
                    gz,
                    ident,
                    num_namespaces_out,
                    capturing_namespace,
                    local_val.inst,
                    local_val.token_src,
                    gpa,
                );

                return rvalue(gz, ri, value_inst, ident);
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
                if (num_namespaces_out != 0 and !local_ptr.maybe_comptime) {
                    const ident_name = try astgen.identifierTokenString(ident_token);
                    return astgen.failNodeNotes(ident, "mutable '{s}' not accessible from here", .{ident_name}, &.{
                        try astgen.errNoteTok(local_ptr.token_src, "declared mutable here", .{}),
                        try astgen.errNoteNode(capturing_namespace.?.node, "crosses namespace boundary here", .{}),
                    });
                }

                const ptr_inst = try tunnelThroughClosure(
                    gz,
                    ident,
                    num_namespaces_out,
                    capturing_namespace,
                    local_ptr.ptr,
                    local_ptr.token_src,
                    gpa,
                );

                switch (ri.rl) {
                    .ref => return ptr_inst,
                    else => {
                        const loaded = try gz.addUnNode(.load, ptr_inst, ident);
                        return rvalue(gz, ri, loaded, ident);
                    },
                }
            }
            s = local_ptr.parent;
        },
        .gen_zir => s = s.cast(GenZir).?.parent,
        .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
        .namespace, .enum_namespace => {
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
            }
            if (s.tag == .namespace) num_namespaces_out += 1;
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
    switch (ri.rl) {
        .ref => return gz.addStrTok(.decl_ref, name_str_index, ident_token),
        else => {
            const result = try gz.addStrTok(.decl_val, name_str_index, ident_token);
            return rvalue(gz, ri, result, ident);
        },
    }
}

/// Adds a capture to a namespace, if needed.
/// Returns the index of the closure_capture instruction.
fn tunnelThroughClosure(
    gz: *GenZir,
    inner_ref_node: Ast.Node.Index,
    num_tunnels: u32,
    ns: ?*Scope.Namespace,
    value: Zir.Inst.Ref,
    token: Ast.TokenIndex,
    gpa: Allocator,
) !Zir.Inst.Ref {
    // For trivial values, we don't need a tunnel.
    // Just return the ref.
    if (num_tunnels == 0 or refToIndex(value) == null) {
        return value;
    }

    // Otherwise we need a tunnel.  Check if this namespace
    // already has one for this value.
    const gop = try ns.?.captures.getOrPut(gpa, refToIndex(value).?);
    if (!gop.found_existing) {
        // Make a new capture for this value but don't add it to the declaring_gz yet
        try gz.astgen.instructions.append(gz.astgen.gpa, .{
            .tag = .closure_capture,
            .data = .{ .un_tok = .{
                .operand = value,
                .src_tok = ns.?.declaring_gz.?.tokenIndexToRelative(token),
            } },
        });
        gop.value_ptr.* = @intCast(Zir.Inst.Index, gz.astgen.instructions.len - 1);
    }

    // Add an instruction to get the value from the closure into
    // our current context
    return try gz.addInstNode(.closure_get, gop.value_ptr.*, inner_ref_node);
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
            0 => .zero,
            1 => .one,
            else => try gz.addInt(num),
        },
        .big_int => |base| big: {
            const gpa = astgen.gpa;
            var big_int = try std.math.big.int.Managed.init(gpa);
            defer big_int.deinit();
            const prefix_offset = @as(u8, 2) * @boolToInt(base != .decimal);
            big_int.setString(@enumToInt(base), bytes[prefix_offset..]) catch |err| switch (err) {
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
            @setFloatMode(.Strict);
            const smaller_float = @floatCast(f64, float_number);
            const bigger_again: f128 = smaller_float;
            if (bigger_again == float_number) {
                const result = try gz.addFloat(smaller_float);
                return rvalue(gz, ri, result, source_node);
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
        .upper_case_base => |i| return astgen.failOff(token, @intCast(u32, i), "base prefix must be lowercase", .{}),
        .invalid_float_base => |i| return astgen.failOff(token, @intCast(u32, i), "invalid base for float literal", .{}),
        .repeated_underscore => |i| return astgen.failOff(token, @intCast(u32, i), "repeated digit separator", .{}),
        .invalid_underscore_after_special => |i| return astgen.failOff(token, @intCast(u32, i), "expected digit before digit separator", .{}),
        .invalid_digit => |info| return astgen.failOff(token, @intCast(u32, info.i), "invalid digit '{c}' for {s} base", .{ bytes[info.i], @tagName(info.base) }),
        .invalid_digit_exponent => |i| return astgen.failOff(token, @intCast(u32, i), "invalid digit '{c}' in exponent", .{bytes[i]}),
        .duplicate_exponent => |i| return astgen.failOff(token, @intCast(u32, i), "duplicate exponent", .{}),
        .exponent_after_underscore => |i| return astgen.failOff(token, @intCast(u32, i), "expected digit before exponent", .{}),
        .special_after_underscore => |i| return astgen.failOff(token, @intCast(u32, i), "expected digit before '{c}'", .{bytes[i]}),
        .trailing_special => |i| return astgen.failOff(token, @intCast(u32, i), "expected digit after '{c}'", .{bytes[i - 1]}),
        .trailing_underscore => |i| return astgen.failOff(token, @intCast(u32, i), "trailing digit separator", .{}),
        .duplicate_period => unreachable, // Validated by tokenizer
        .invalid_character => unreachable, // Validated by tokenizer
        .invalid_exponent_sign => |i| {
            assert(bytes.len >= 2 and bytes[0] == '0' and bytes[1] == 'x'); // Validated by tokenizer
            return astgen.failOff(token, @intCast(u32, i), "sign '{c}' cannot follow digit '{c}' in hex base", .{ bytes[i], bytes[i - 1] });
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

    const TagAndTmpl = struct { tag: Zir.Inst.Extended, tmpl: u32 };
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
            .tmpl = @enumToInt(try comptimeExpr(gz, scope, .{ .rl = .none }, full.ast.template)),
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
            output_type_bits |= @as(u32, 1) << @intCast(u5, i);
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
            clobbers_buffer[clobber_i] = (try astgen.strLitAsString(tok_i)).index;
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
    switch (ri.rl) {
        .none, .discard, .ref, .ty, .coerced_ty => {
            const result = try reachableExpr(gz, scope, .{ .rl = .{ .ty = dest_type } }, rhs, node);
            return rvalue(gz, ri, result, node);
        },
        .ptr => |result_ptr| {
            return asRlPtr(gz, scope, ri, node, result_ptr.inst, rhs, dest_type);
        },
        .inferred_ptr => |result_ptr| {
            return asRlPtr(gz, scope, ri, node, result_ptr, rhs, dest_type);
        },
        .block_ptr => |block_scope| {
            return asRlPtr(gz, scope, ri, node, block_scope.rl_ptr, rhs, dest_type);
        },
    }
}

fn unionInit(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const union_type = try typeExpr(gz, scope, params[0]);
    const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[1]);
    const field_type = try gz.addPlNode(.field_type_ref, params[1], Zir.Inst.FieldTypeRef{
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

fn asRlPtr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    src_node: Ast.Node.Index,
    result_ptr: Zir.Inst.Ref,
    operand_node: Ast.Node.Index,
    dest_type: Zir.Inst.Ref,
) InnerError!Zir.Inst.Ref {
    var as_scope = try parent_gz.makeCoercionScope(scope, dest_type, result_ptr, src_node);
    defer as_scope.unstack();

    const result = try reachableExpr(&as_scope, &as_scope.base, .{ .rl = .{ .block_ptr = &as_scope } }, operand_node, src_node);
    return as_scope.finishCoercion(parent_gz, ri, operand_node, result, dest_type);
}

fn bitCast(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs: Ast.Node.Index,
    rhs: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const dest_type = try reachableTypeExpr(gz, scope, lhs, node);
    const operand = try reachableExpr(gz, scope, .{ .rl = .none }, rhs, node);
    const result = try gz.addPlNode(.bitcast, node, Zir.Inst.Bin{
        .lhs = dest_type,
        .rhs = operand,
    });
    return rvalue(gz, ri, result, node);
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
        typeof_scope.c_import = false;
        defer typeof_scope.unstack();

        const ty_expr = try reachableExpr(&typeof_scope, &typeof_scope.base, .{ .rl = .none }, args[0], node);
        if (!gz.refIsNoReturn(ty_expr)) {
            _ = try typeof_scope.addBreak(.break_inline, typeof_inst, ty_expr);
        }
        try typeof_scope.setBlockBody(typeof_inst);

        // typeof_scope unstacked now, can add new instructions to gz
        try gz.instructions.append(gpa, typeof_inst);
        return rvalue(gz, ri, indexToRef(typeof_inst), node);
    }
    const payload_size: u32 = std.meta.fields(Zir.Inst.TypeOfPeer).len;
    const payload_index = try reserveExtra(astgen, payload_size + args.len);
    var args_index = payload_index + payload_size;

    const typeof_inst = try gz.addExtendedMultiOpPayloadIndex(.typeof_peer, payload_index, args.len);

    var typeof_scope = gz.makeSubBlock(scope);
    typeof_scope.is_comptime = false;

    for (args, 0..) |arg, i| {
        const param_ref = try reachableExpr(&typeof_scope, &typeof_scope.base, .{ .rl = .none }, arg, node);
        astgen.extra.items[args_index + i] = @enumToInt(param_ref);
    }
    _ = try typeof_scope.addBreak(.break_inline, refToIndex(typeof_inst).?, .void_value);

    const body = typeof_scope.instructionsSlice();
    const body_len = astgen.countBodyLenAfterFixups(body);
    astgen.setExtra(payload_index, Zir.Inst.TypeOfPeer{
        .body_len = @intCast(u32, body_len),
        .body_index = @intCast(u32, astgen.extra.items.len),
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
        astgen.extra.items[extra_index] = @enumToInt(arg_ref);
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
            const str_slice = astgen.string_bytes.items[str.index..][0..str.len];
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
                astgen.extra.items[extra_index] = @enumToInt(param_ref);
                extra_index += 1;
            }
            const result = try gz.addExtendedMultiOpPayloadIndex(.compile_log, payload_index, params.len);
            return rvalue(gz, ri, result, node);
        },
        .field => {
            if (ri.rl == .ref) {
                return gz.addPlNode(.field_ptr_named, node, Zir.Inst.FieldNamed{
                    .lhs = try expr(gz, scope, .{ .rl = .ref }, params[0]),
                    .field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[1]),
                });
            }
            const result = try gz.addPlNode(.field_val_named, node, Zir.Inst.FieldNamed{
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },

        // zig fmt: off
        .as         => return as(       gz, scope, ri, node, params[0], params[1]),
        .bit_cast   => return bitCast(  gz, scope, ri, node, params[0], params[1]),
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
            var decl_name: u32 = 0;
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
                        .namespace, .enum_namespace => {
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
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .export_options_type } }, params[1]);
            _ = try gz.addPlNode(.@"export", node, Zir.Inst.Export{
                .namespace = namespace,
                .decl_name = decl_name,
                .options = options,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .@"extern" => {
            const type_inst = try typeExpr(gz, scope, params[0]);
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .extern_options_type } }, params[1]);
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
            const order = try expr(gz, scope, align_ri, params[0]);
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

        .ptr_to_int            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .ptr_to_int),
        .compile_error         => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[0], .compile_error),
        .set_eval_branch_quota => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .u32_type } },    params[0], .set_eval_branch_quota),
        .enum_to_int           => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .enum_to_int),
        .bool_to_int           => return simpleUnOp(gz, scope, ri, node, bool_ri,                                    params[0], .bool_to_int),
        .embed_file            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[0], .embed_file),
        .error_name            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .ty = .anyerror_type } },       params[0], .error_name),
        .set_runtime_safety    => return simpleUnOp(gz, scope, ri, node, bool_ri,                                    params[0], .set_runtime_safety),
        .sqrt                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .sqrt),
        .sin                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .sin),
        .cos                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .cos),
        .tan                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .tan),
        .exp                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .exp),
        .exp2                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .exp2),
        .log                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .log),
        .log2                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .log2),
        .log10                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .log10),
        .fabs                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .fabs),
        .floor                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .floor),
        .ceil                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .ceil),
        .trunc                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .trunc),
        .round                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .round),
        .tag_name              => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .tag_name),
        .type_name             => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .type_name),
        .Frame                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .frame_type),
        .frame_size            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                           params[0], .frame_size),

        .float_to_int => return typeCast(gz, scope, ri, node, params[0], params[1], .float_to_int),
        .int_to_float => return typeCast(gz, scope, ri, node, params[0], params[1], .int_to_float),
        .int_to_ptr   => return typeCast(gz, scope, ri, node, params[0], params[1], .int_to_ptr),
        .int_to_enum  => return typeCast(gz, scope, ri, node, params[0], params[1], .int_to_enum),
        .float_cast   => return typeCast(gz, scope, ri, node, params[0], params[1], .float_cast),
        .int_cast     => return typeCast(gz, scope, ri, node, params[0], params[1], .int_cast),
        .ptr_cast     => return typeCast(gz, scope, ri, node, params[0], params[1], .ptr_cast),
        .truncate     => return typeCast(gz, scope, ri, node, params[0], params[1], .truncate),
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
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = .extended,
                .data = .{ .extended = .{
                    .opcode = .reify,
                    .small = @enumToInt(gz.anon_name_strategy),
                    .operand = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            const result = indexToRef(new_index);
            return rvalue(gz, ri, result, node);
        },
        .panic => {
            try emitDbgNode(gz, node);
            return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[0], .panic);
        },
        .trap => {
            try emitDbgNode(gz, node);
            _ = try gz.addNode(.trap, node);
            return rvalue(gz, ri, .void_value, node);
        },
        .error_to_int => {
            const operand = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const result = try gz.addExtendedPayload(.error_to_int, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .int_to_error => {
            const operand = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .u16_type } }, params[0]);
            const result = try gz.addExtendedPayload(.int_to_error, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .align_cast => {
            const dest_align = try comptimeExpr(gz, scope, align_ri, params[0]);
            const rhs = try expr(gz, scope, .{ .rl = .none }, params[1]);
            const result = try gz.addPlNode(.align_cast, node, Zir.Inst.Bin{
                .lhs = dest_align,
                .rhs = rhs,
            });
            return rvalue(gz, ri, result, node);
        },
        .err_set_cast => {
            try emitDbgNode(gz, node);

            const result = try gz.addExtendedPayload(.err_set_cast, Zir.Inst.BinNode{
                .lhs = try typeExpr(gz, scope, params[0]),
                .rhs = try expr(gz, scope, .{ .rl = .none }, params[1]),
                .node = gz.nodeIndexToRelative(node),
            });
            return rvalue(gz, ri, result, node);
        },
        .addrspace_cast => {
            const result = try gz.addExtendedPayload(.addrspace_cast, Zir.Inst.BinNode{
                .lhs = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .address_space_type } }, params[0]),
                .rhs = try expr(gz, scope, .{ .rl = .none }, params[1]),
                .node = gz.nodeIndexToRelative(node),
            });
            return rvalue(gz, ri, result, node);
        },
        .const_cast => {
            const operand = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const result = try gz.addExtendedPayload(.const_cast, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .volatile_cast => {
            const operand = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const result = try gz.addExtendedPayload(.volatile_cast, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },

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

        .bit_offset_of  => return offsetOf(gz, scope, ri, node, params[0], params[1], .bit_offset_of),
        .offset_of => return offsetOf(gz, scope, ri, node, params[0], params[1], .offset_of),

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
            const delta_arg = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[1]);
            const result = try gz.addExtendedPayload(.wasm_memory_grow, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = index_arg,
                .rhs = delta_arg,
            });
            return rvalue(gz, ri, result, node);
        },
        .c_define => {
            if (!gz.c_import) return gz.astgen.failNode(node, "C define valid only inside C import block", .{});
            const name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[0]);
            const value = try comptimeExpr(gz, scope, .{ .rl = .none }, params[1]);
            const result = try gz.addExtendedPayload(.c_define, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = name,
                .rhs = value,
            });
            return rvalue(gz, ri, result, node);
        },

        .splat => {
            const len = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const scalar = try expr(gz, scope, .{ .rl = .none }, params[1]);
            const result = try gz.addPlNode(.splat, node, Zir.Inst.Bin{
                .lhs = len,
                .rhs = scalar,
            });
            return rvalue(gz, ri, result, node);
        },
        .reduce => {
            const op = try expr(gz, scope, .{ .rl = .{ .ty = .reduce_op_type } }, params[0]);
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
            const modifier = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .modifier_type } }, params[0]);
            const callee = try calleeExpr(gz, scope, params[1]);
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
            const parent_type = try typeExpr(gz, scope, params[0]);
            const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[1]);
            const result = try gz.addPlNode(.field_parent_ptr, node, Zir.Inst.FieldParentPtr{
                .parent_type = parent_type,
                .field_name = field_name,
                .field_ptr = try expr(gz, scope, .{ .rl = .none }, params[2]),
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
            _ = try gz.addPlNode(.memset, node, Zir.Inst.Bin{
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .rhs = try expr(gz, scope, .{ .rl = .none }, params[1]),
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
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .prefetch_options_type } }, params[1]);
            _ = try gz.addExtendedPayload(.prefetch, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = ptr,
                .rhs = options,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .c_va_arg => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@cVaArg' outside function scope", .{});
            }
            const result = try gz.addExtendedPayload(.c_va_arg, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .rhs = try typeExpr(gz, scope, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_copy => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@cVaCopy' outside function scope", .{});
            }
            const result = try gz.addExtendedPayload(.c_va_copy, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = try expr(gz, scope, .{ .rl = .none }, params[0]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_end => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@cVaEnd' outside function scope", .{});
            }
            const result = try gz.addExtendedPayload(.c_va_end, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = try expr(gz, scope, .{ .rl = .none }, params[0]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_start => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@cVaStart' outside function scope", .{});
            }
            if (!astgen.fn_var_args) {
                return astgen.failNode(node, "'@cVaStart' in a non-variadic function", .{});
            }
            return rvalue(gz, ri, try gz.addNodeExtended(.c_va_start, node), node);
        },

        .work_item_id => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@workItemId' outside function scope", .{});
            }
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.work_item_id, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .work_group_size => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@workGroupSize' outside function scope", .{});
            }
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.work_group_size, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .work_group_id => {
            if (astgen.fn_block == null) {
                return astgen.failNode(node, "'@workGroupId' outside function scope", .{});
            }
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
    const name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, rhs_node);
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
    lhs_node: Ast.Node.Index,
    rhs_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
    const result_type = try typeExpr(gz, scope, lhs_node);
    const operand = try expr(gz, scope, .{ .rl = .none }, rhs_node);

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
        .tag_name, .error_name, .ptr_to_int => try emitDbgStmt(gz, cursor),
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
    const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, operand_node);
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
    const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, rhs_node);
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
    const block_result = try expr(&block_scope, &block_scope.base, .{ .rl = .none }, body_node);
    _ = try gz.addUnNode(.ensure_result_used, block_result, node);
    if (!gz.refIsNoReturn(block_result)) {
        _ = try block_scope.addBreak(.break_inline, block_inst, .void_value);
    }
    try block_scope.setBlockBody(block_inst);
    // block_scope unstacked now, can add new instructions to gz
    try gz.instructions.append(gpa, block_inst);

    return indexToRef(block_inst);
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

        _ = try gz.add(.{ .tag = .dbg_stmt, .data = .{
            .dbg_stmt = .{
                .line = line,
                .column = column,
            },
        } });
    }

    assert(callee != .none);
    assert(node != 0);

    const call_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
    const call_inst = Zir.indexToRef(call_index);
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
        arg_block.rl_ty_inst = call_inst;
        const arg_ref = try expr(&arg_block, &arg_block.base, .{ .rl = .{ .coerced_ty = call_inst }, .ctx = .fn_arg }, param_node);
        _ = try arg_block.addBreakWithSrcNode(.break_inline, call_index, arg_ref, param_node);

        const body = arg_block.instructionsSlice();
        try astgen.scratch.ensureUnusedCapacity(astgen.gpa, countBodyLenAfterFixups(astgen, body));
        appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);

        astgen.scratch.items[scratch_index] = @intCast(u32, astgen.scratch.items.len - scratch_top);
        scratch_index += 1;
    }

    // If our result location is a try/catch/error-union-if/return, a function argument,
    // or an initializer for a `const` variable, the error trace propagates.
    // Otherwise, it should always be popped (handled in Sema).
    const propagate_error_trace = switch (ri.ctx) {
        .error_handling_expr, .@"return", .fn_arg, .const_init => true,
        else => false,
    };

    const payload_index = try addExtra(astgen, Zir.Inst.Call{
        .callee = callee,
        .flags = .{
            .pop_error_return_trace = !propagate_error_trace,
            .packed_modifier = @intCast(Zir.Inst.Call.Flags.PackedModifier, @enumToInt(modifier)),
            .args_len = @intCast(Zir.Inst.Call.Flags.PackedArgsLen, call.ast.params.len),
        },
    });
    if (call.ast.params.len != 0) {
        try astgen.extra.appendSlice(astgen.gpa, astgen.scratch.items[scratch_top..]);
    }
    gz.astgen.instructions.set(call_index, .{
        .tag = .call,
        .data = .{ .pl_node = .{
            .src_node = gz.nodeIndexToRelative(node),
            .payload_index = payload_index,
        } },
    });
    return rvalue(gz, ri, call_inst, node); // TODO function call with result location
}

/// calleeExpr generates the function part of a call expression (f in f(x)), or the
/// callee argument to the @call() builtin. If the lhs is a field access or the
/// @field() builtin, we need to generate a special field_call_bind instruction
/// instead of the normal field_val or field_ptr.  If this is a inst.func() call,
/// this instruction will capture the value of the first argument before evaluating
/// the other arguments. We need to use .ref here to guarantee we will be able to
/// promote an lvalue to an address if the first parameter requires it.  This
/// unfortunately also means we need to take a reference to any types on the lhs.
fn calleeExpr(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const tag = tree.nodes.items(.tag)[node];
    switch (tag) {
        .field_access => return addFieldAccess(.field_call_bind, gz, scope, .{ .rl = .ref }, node),

        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => {
            const node_datas = tree.nodes.items(.data);
            const main_tokens = tree.nodes.items(.main_token);
            const builtin_token = main_tokens[node];
            const builtin_name = tree.tokenSlice(builtin_token);

            var inline_params: [2]Ast.Node.Index = undefined;
            var params: []Ast.Node.Index = switch (tag) {
                .builtin_call,
                .builtin_call_comma,
                => tree.extra_data[node_datas[node].lhs..node_datas[node].rhs],

                .builtin_call_two,
                .builtin_call_two_comma,
                => blk: {
                    inline_params = .{ node_datas[node].lhs, node_datas[node].rhs };
                    const len: usize = if (inline_params[0] == 0) @as(usize, 0) else if (inline_params[1] == 0) @as(usize, 1) else @as(usize, 2);
                    break :blk inline_params[0..len];
                },

                else => unreachable,
            };

            // If anything is wrong, fall back to builtinCall.
            // It will emit any necessary compile errors and notes.
            if (std.mem.eql(u8, builtin_name, "@field") and params.len == 2) {
                const lhs = try expr(gz, scope, .{ .rl = .ref }, params[0]);
                const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = .const_slice_u8_type } }, params[1]);
                return gz.addExtendedPayload(.field_call_bind_named, Zir.Inst.FieldNamedNode{
                    .node = gz.nodeIndexToRelative(node),
                    .lhs = lhs,
                    .field_name = field_name,
                });
            }

            return builtinCall(gz, scope, .{ .rl = .none }, node, params);
        },
        else => return expr(gz, scope, .{ .rl = .none }, node),
    }
}

const primitive_instrs = std.ComptimeStringMap(Zir.Inst.Ref, .{
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
    for (primitive_instrs.kvs) |kv| {
        if (!primitives.isPrimitive(kv.key)) {
            @compileError("std.zig.isPrimitive() is not aware of Zir instr '" ++ @tagName(kv.value) ++ "'");
        }
    }
    for (primitives.names.kvs) |kv| {
        if (primitive_instrs.get(kv.key) == null) {
            @compileError("std.zig.primitives entry '" ++ kv.key ++ "' does not have a corresponding Zir instr");
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

fn nodeMayNeedMemoryLocation(tree: *const Ast, start_node: Ast.Node.Index, have_res_ty: bool) bool {
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
            .add_sat,
            .array_cat,
            .array_mult,
            .assign,
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

            // Array and struct init exprs write to result locs, but anon literals do not.
            .array_init_one,
            .array_init_one_comma,
            .struct_init_one,
            .struct_init_one_comma,
            .array_init,
            .array_init_comma,
            .struct_init,
            .struct_init_comma,
            => return have_res_ty or node_datas[node].lhs != 0,

            // Anon literals do not need result location.
            .array_init_dot_two,
            .array_init_dot_two_comma,
            .array_init_dot,
            .array_init_dot_comma,
            .struct_init_dot_two,
            .struct_init_dot_two_comma,
            .struct_init_dot,
            .struct_init_dot_comma,
            => return have_res_ty,

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

            .builtin_call_two, .builtin_call_two_comma => {
                const builtin_token = main_tokens[node];
                const builtin_name = tree.tokenSlice(builtin_token);
                // If the builtin is an invalid name, we don't cause an error here; instead
                // let it pass, and the error will be "invalid builtin function" later.
                const builtin_info = BuiltinFn.list.get(builtin_name) orelse return false;
                switch (builtin_info.needs_mem_loc) {
                    .never => return false,
                    .always => return true,
                    .forward1 => node = node_datas[node].rhs,
                }
                // Missing builtin arg is not a parsing error, expect an error later.
                if (node == 0) return false;
            },

            .builtin_call, .builtin_call_comma => {
                const params = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
                const builtin_token = main_tokens[node];
                const builtin_name = tree.tokenSlice(builtin_token);
                // If the builtin is an invalid name, we don't cause an error here; instead
                // let it pass, and the error will be "invalid builtin function" later.
                const builtin_info = BuiltinFn.list.get(builtin_name) orelse return false;
                switch (builtin_info.needs_mem_loc) {
                    .never => return false,
                    .always => return true,
                    .forward1 => node = params[1],
                }
                // Missing builtin arg is not a parsing error, expect an error later.
                if (node == 0) return false;
            },
        }
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
/// As an example, if the `ResultLoc` is `ptr`, it will write the result to the pointer.
/// If the `ResultLoc` is `ty`, it will coerce the result to the type.
/// Assumes nothing stacked on `gz`.
fn rvalue(
    gz: *GenZir,
    ri: ResultInfo,
    raw_result: Zir.Inst.Ref,
    src_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const result = r: {
        if (refToIndex(raw_result)) |result_index| {
            const zir_tags = gz.astgen.instructions.items(.tag);
            const data = gz.astgen.instructions.items(.data)[result_index];
            if (zir_tags[result_index].isAlwaysVoid(data)) {
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
            return result;
        },
        .ref => {
            // We need a pointer but we have a value.
            // Unfortunately it's not quite as simple as directly emitting a ref
            // instruction here because we need subsequent address-of operator on
            // const locals to return the same address.
            const astgen = gz.astgen;
            const tree = astgen.tree;
            const src_token = tree.firstToken(src_node);
            const result_index = refToIndex(result) orelse
                return gz.addUnTok(.ref, result, src_token);
            const zir_tags = gz.astgen.instructions.items(.tag);
            if (zir_tags[result_index].isParam() or astgen.isInferred(result))
                return gz.addUnTok(.ref, result, src_token);
            const gop = try astgen.ref_table.getOrPut(astgen.gpa, result_index);
            if (!gop.found_existing) {
                gop.value_ptr.* = try gz.makeUnTok(.ref, result, src_token);
            }
            return indexToRef(gop.value_ptr.*);
        },
        .ty => |ty_inst| {
            // Quickly eliminate some common, unnecessary type coercion.
            const as_ty = @as(u64, @enumToInt(Zir.Inst.Ref.type_type)) << 32;
            const as_comptime_int = @as(u64, @enumToInt(Zir.Inst.Ref.comptime_int_type)) << 32;
            const as_bool = @as(u64, @enumToInt(Zir.Inst.Ref.bool_type)) << 32;
            const as_usize = @as(u64, @enumToInt(Zir.Inst.Ref.usize_type)) << 32;
            const as_void = @as(u64, @enumToInt(Zir.Inst.Ref.void_type)) << 32;
            switch ((@as(u64, @enumToInt(ty_inst)) << 32) | @as(u64, @enumToInt(result))) {
                as_ty | @enumToInt(Zir.Inst.Ref.u1_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u8_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i8_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u16_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u29_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i16_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u32_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i32_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u64_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i64_type),
                as_ty | @enumToInt(Zir.Inst.Ref.usize_type),
                as_ty | @enumToInt(Zir.Inst.Ref.isize_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_char_type),
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
                as_ty | @enumToInt(Zir.Inst.Ref.f80_type),
                as_ty | @enumToInt(Zir.Inst.Ref.f128_type),
                as_ty | @enumToInt(Zir.Inst.Ref.anyopaque_type),
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
                offset + @intCast(u32, bad_index),
                "invalid escape character: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .expected_hex_digit => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected hex digit, found '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .empty_unicode_escape_sequence => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "empty unicode escape sequence",
                .{},
            );
        },
        .expected_hex_digit_or_rbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected hex digit or '}}', found '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .invalid_unicode_codepoint => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "unicode escape does not correspond to a valid codepoint",
                .{},
            );
        },
        .expected_lbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected '{{', found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .expected_rbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected '}}', found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .expected_single_quote => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected single quote ('), found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .invalid_character => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
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
    const msg = @intCast(u32, string_bytes.items.len);
    try string_bytes.writer(astgen.gpa).print(format ++ "\x00", args);
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureTotalCapacity(astgen.gpa, notes_start + 1 + notes.len);
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
    const msg = @intCast(u32, string_bytes.items.len);
    try string_bytes.writer(gpa).print(format ++ "\x00", args);
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureTotalCapacity(gpa, notes_start + 1 + notes.len);
        astgen.extra.appendAssumeCapacity(@intCast(u32, notes.len));
        astgen.extra.appendSliceAssumeCapacity(notes);
        break :blk @intCast(u32, notes_start);
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
    const msg = @intCast(u32, string_bytes.items.len);
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
    const msg = @intCast(u32, string_bytes.items.len);
    try string_bytes.writer(astgen.gpa).print(format ++ "\x00", args);
    return astgen.addExtra(Zir.Inst.CompileErrors.Item{
        .msg = msg,
        .node = node,
        .token = 0,
        .byte_offset = 0,
        .notes = 0,
    });
}

fn identAsString(astgen: *AstGen, ident_token: Ast.TokenIndex) !u32 {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index = @intCast(u32, string_bytes.items.len);
    try astgen.appendIdentStr(ident_token, string_bytes);
    const key = string_bytes.items[str_index..];
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, @as([]const u8, key), StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return gop.key_ptr.*;
    } else {
        gop.key_ptr.* = str_index;
        try string_bytes.append(gpa, 0);
        return str_index;
    }
}

/// Adds a doc comment block to `string_bytes` by walking backwards from `end_token`.
/// `end_token` must point at the first token after the last doc coment line.
/// Returns 0 if no doc comment is present.
fn docCommentAsString(astgen: *AstGen, end_token: Ast.TokenIndex) !u32 {
    if (end_token == 0) return @as(u32, 0);

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
) !u32 {
    if (start_token == end_token) return 0;

    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index = @intCast(u32, string_bytes.items.len);
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

    const key = string_bytes.items[str_index..];
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, @as([]const u8, key), StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });

    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return gop.key_ptr.*;
    } else {
        gop.key_ptr.* = str_index;
        try string_bytes.append(gpa, 0);
        return str_index;
    }
}

const IndexSlice = struct { index: u32, len: u32 };

fn strLitAsString(astgen: *AstGen, str_lit_token: Ast.TokenIndex) !IndexSlice {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index = @intCast(u32, string_bytes.items.len);
    const token_bytes = astgen.tree.tokenSlice(str_lit_token);
    try astgen.parseStrLit(str_lit_token, string_bytes, token_bytes, 0);
    const key = string_bytes.items[str_index..];
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, @as([]const u8, key), StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return IndexSlice{
            .index = gop.key_ptr.*,
            .len = @intCast(u32, key.len),
        };
    } else {
        gop.key_ptr.* = str_index;
        // Still need a null byte because we are using the same table
        // to lookup null terminated strings, so if we get a match, it has to
        // be null terminated for that to work.
        try string_bytes.append(gpa, 0);
        return IndexSlice{
            .index = str_index,
            .len = @intCast(u32, key.len),
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
        .index = @intCast(u32, str_index),
        .len = @intCast(u32, len),
    };
}

fn testNameString(astgen: *AstGen, str_lit_token: Ast.TokenIndex) !u32 {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index = @intCast(u32, string_bytes.items.len);
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
    return str_index;
}

const Scope = struct {
    tag: Tag,

    fn cast(base: *Scope, comptime T: type) ?*T {
        if (T == Defer) {
            switch (base.tag) {
                .defer_normal, .defer_error => return @fieldParentPtr(T, "base", base),
                else => return null,
            }
        }
        if (T == Namespace) {
            switch (base.tag) {
                .namespace, .enum_namespace => return @fieldParentPtr(T, "base", base),
                else => return null,
            }
        }
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    fn parent(base: *Scope) ?*Scope {
        return switch (base.tag) {
            .gen_zir => base.cast(GenZir).?.parent,
            .local_val => base.cast(LocalVal).?.parent,
            .local_ptr => base.cast(LocalPtr).?.parent,
            .defer_normal, .defer_error => base.cast(Defer).?.parent,
            .namespace, .enum_namespace => base.cast(Namespace).?.parent,
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
        enum_namespace,
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
        name: u32,
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
        /// String table index.
        name: u32,
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
        remapped_err_code: Zir.Inst.Index = 0,
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
        decls: std.AutoHashMapUnmanaged(u32, Ast.Node.Index) = .{},
        node: Ast.Node.Index,
        inst: Zir.Inst.Index,

        /// The astgen scope containing this namespace.
        /// Only valid during astgen.
        declaring_gz: ?*GenZir,

        /// Map from the raw captured value to the instruction
        /// ref of the capture for decls in this namespace
        captures: std.AutoArrayHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{},

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
    /// This is set to true for inline loops; false otherwise.
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
    break_block: Zir.Inst.Index = 0,
    continue_block: Zir.Inst.Index = 0,
    /// Only valid when setBreakResultInfo is called.
    break_result_info: AstGen.ResultInfo = undefined,
    /// When a block has a pointer result location, here it is.
    rl_ptr: Zir.Inst.Ref = .none,
    /// When a block has a type result location, here it is.
    rl_ty_inst: Zir.Inst.Ref = .none,
    /// Keeps track of how many branches of a block did not actually
    /// consume the result location. astgen uses this to figure out
    /// whether to rely on break instructions or writing to the result
    /// pointer for the result instruction.
    rvalue_rl_count: usize = 0,
    /// Keeps track of how many break instructions there are. When astgen is finished
    /// with a block, it can check this against rvalue_rl_count to find out whether
    /// the break instructions should be downgraded to break_void.
    break_count: usize = 0,
    /// Tracks `break :foo bar` instructions so they can possibly be elided later if
    /// the labeled block ends up not needing a result location pointer.
    labeled_breaks: ArrayListUnmanaged(struct { br: Zir.Inst.Index, search: Zir.Inst.Index }) = .{},

    suspend_node: Ast.Node.Index = 0,
    nosuspend_node: Ast.Node.Index = 0,
    /// Set if this GenZir is a defer.
    cur_defer_node: Ast.Node.Index = 0,
    // Set if this GenZir is a defer or it is inside a defer.
    any_defer_node: Ast.Node.Index = 0,

    /// Namespace members are lazy.  When executing a decl within a namespace,
    /// any references to external instructions need to be treated specially.
    /// This list tracks those references.  See also .closure_capture and .closure_get.
    /// Keys are the raw instruction index, values are the closure_capture instruction.
    captures: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{},

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
            .c_import = gz.c_import,
            .decl_node_index = gz.decl_node_index,
            .decl_line = gz.decl_line,
            .parent = scope,
            .rl_ty_inst = gz.rl_ty_inst,
            .astgen = gz.astgen,
            .suspend_node = gz.suspend_node,
            .nosuspend_node = gz.nosuspend_node,
            .any_defer_node = gz.any_defer_node,
            .instructions = gz.instructions,
            .instructions_top = gz.instructions.items.len,
        };
    }

    fn makeCoercionScope(
        parent_gz: *GenZir,
        scope: *Scope,
        dest_type: Zir.Inst.Ref,
        result_ptr: Zir.Inst.Ref,
        src_node: Ast.Node.Index,
    ) !GenZir {
        // Detect whether this expr() call goes into rvalue() to store the result into the
        // result location. If it does, elide the coerce_result_ptr instruction
        // as well as the store instruction, instead passing the result as an rvalue.
        var as_scope = parent_gz.makeSubBlock(scope);
        errdefer as_scope.unstack();
        as_scope.rl_ptr = try as_scope.addPlNode(.coerce_result_ptr, src_node, Zir.Inst.Bin{ .lhs = dest_type, .rhs = result_ptr });

        // `rl_ty_inst` needs to be set in case the stores to `rl_ptr` are eliminated.
        as_scope.rl_ty_inst = dest_type;

        return as_scope;
    }

    /// Assumes `as_scope` is stacked immediately on top of `parent_gz`. Unstacks `as_scope`.
    fn finishCoercion(
        as_scope: *GenZir,
        parent_gz: *GenZir,
        ri: ResultInfo,
        src_node: Ast.Node.Index,
        result: Zir.Inst.Ref,
        dest_type: Zir.Inst.Ref,
    ) InnerError!Zir.Inst.Ref {
        assert(as_scope.instructions == parent_gz.instructions);
        const astgen = as_scope.astgen;
        if (as_scope.rvalue_rl_count == 1) {
            // Busted! This expression didn't actually need a pointer.
            const zir_tags = astgen.instructions.items(.tag);
            const zir_datas = astgen.instructions.items(.data);
            var src: usize = as_scope.instructions_top;
            var dst: usize = src;
            while (src < as_scope.instructions.items.len) : (src += 1) {
                const src_inst = as_scope.instructions.items[src];
                if (indexToRef(src_inst) == as_scope.rl_ptr) continue;
                if (zir_tags[src_inst] == .store_to_block_ptr) {
                    if (zir_datas[src_inst].bin.lhs == as_scope.rl_ptr) continue;
                }
                as_scope.instructions.items[dst] = src_inst;
                dst += 1;
            }
            parent_gz.instructions.items.len -= src - dst;
            as_scope.instructions_top = GenZir.unstacked_top;
            // as_scope now unstacked, can add new instructions to parent_gz
            const casted_result = try parent_gz.addBin(.as, dest_type, result);
            return rvalue(parent_gz, ri, casted_result, src_node);
        } else {
            // implicitly move all as_scope instructions to parent_gz
            as_scope.instructions_top = GenZir.unstacked_top;
            return result;
        }
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
        return tags[last_inst].isNoReturn();
    }

    /// TODO all uses of this should be replaced with uses of `endsWithNoReturn`.
    fn refIsNoReturn(gz: GenZir, inst_ref: Zir.Inst.Ref) bool {
        if (inst_ref == .unreachable_value) return true;
        if (refToIndex(inst_ref)) |inst_index| {
            return gz.astgen.instructions.items(.tag)[inst_index].isNoReturn();
        }
        return false;
    }

    fn nodeIndexToRelative(gz: GenZir, node_index: Ast.Node.Index) i32 {
        return @bitCast(i32, node_index) - @bitCast(i32, gz.decl_node_index);
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
        // One more complication: when the result location is a pointer, we detect
        // the scenario where the result location is not consumed. In this case
        // we emit ZIR for the block break instructions to have the result values,
        // and then rvalue() on that to pass the value to the result location.
        switch (parent_ri.rl) {
            .coerced_ty => |ty_inst| {
                // Type coercion needs to happend before breaks.
                gz.rl_ty_inst = ty_inst;
                gz.break_result_info = .{ .rl = .{ .ty = ty_inst } };
            },
            .ty => |ty_inst| {
                gz.rl_ty_inst = ty_inst;
                gz.break_result_info = parent_ri;
            },

            .none, .ref => {
                gz.rl_ty_inst = .none;
                gz.break_result_info = parent_ri;
            },

            .discard => {
                gz.rl_ty_inst = .none;
                gz.break_result_info = .{ .rl = .discard };
            },

            .ptr => |ptr_res| {
                gz.rl_ty_inst = .none;
                gz.break_result_info = .{ .rl = .{ .ptr = .{ .inst = ptr_res.inst } }, .ctx = parent_ri.ctx };
            },

            .inferred_ptr => |ptr| {
                gz.rl_ty_inst = .none;
                gz.rl_ptr = ptr;
                gz.break_result_info = .{ .rl = .{ .block_ptr = gz }, .ctx = parent_ri.ctx };
            },

            .block_ptr => |parent_block_scope| {
                gz.rl_ty_inst = parent_block_scope.rl_ty_inst;
                gz.rl_ptr = parent_block_scope.rl_ptr;
                gz.break_result_info = .{ .rl = .{ .block_ptr = gz }, .ctx = parent_ri.ctx };
            },
        }
    }

    /// Assumes nothing stacked on `gz`. Unstacks `gz`.
    fn setBoolBrBody(gz: *GenZir, inst: Zir.Inst.Index) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        const body = gz.instructionsSlice();
        const body_len = astgen.countBodyLenAfterFixups(body);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.Block).Struct.fields.len + body_len,
        );
        const zir_datas = astgen.instructions.items(.data);
        zir_datas[inst].bool_br.payload_index = astgen.addExtraAssumeCapacity(
            Zir.Inst.Block{ .body_len = body_len },
        );
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
        zir_datas[inst].pl_node.payload_index = astgen.addExtraAssumeCapacity(
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
        zir_datas[inst].pl_node.payload_index = astgen.addExtraAssumeCapacity(
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

        lib_name: u32,
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
        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);

        try astgen.instructions.ensureUnusedCapacity(gpa, 1);

        var body: []Zir.Inst.Index = &[0]Zir.Inst.Index{};
        var ret_body: []Zir.Inst.Index = &[0]Zir.Inst.Index{};
        var src_locs_buffer: [3]u32 = undefined;
        var src_locs: []u32 = src_locs_buffer[0..0];
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
            const rbrace_line = @intCast(u32, astgen.source_line - gz.decl_line);
            const rbrace_column = @intCast(u32, astgen.source_column);

            const columns = args.lbrace_column | (rbrace_column << 16);
            src_locs_buffer[0] = args.lbrace_line;
            src_locs_buffer[1] = rbrace_line;
            src_locs_buffer[2] = columns;
            src_locs = &src_locs_buffer;

            body = body_gz.instructionsSlice();
            if (args.ret_gz) |ret_gz|
                ret_body = ret_gz.instructionsSliceUpto(body_gz);
        } else {
            if (args.ret_gz) |ret_gz|
                ret_body = ret_gz.instructionsSlice();
        }
        const body_len = astgen.countBodyLenAfterFixups(body);

        if (args.cc_ref != .none or args.lib_name != 0 or args.is_var_args or args.is_test or
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
                    body_len + src_locs.len +
                    @boolToInt(args.lib_name != 0) +
                    @boolToInt(args.noalias_bits != 0),
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
                    .has_lib_name = args.lib_name != 0,
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
            if (args.lib_name != 0) {
                astgen.extra.appendAssumeCapacity(args.lib_name);
            }

            const zir_datas = astgen.instructions.items(.data);
            if (align_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, align_body));
                astgen.appendBodyWithFixups(align_body);
                const inst_data = zir_datas[align_body[align_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (args.align_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.align_ref));
            }
            if (addrspace_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, addrspace_body));
                astgen.appendBodyWithFixups(addrspace_body);
                const inst_data = zir_datas[addrspace_body[addrspace_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (args.addrspace_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.addrspace_ref));
            }
            if (section_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, section_body));
                astgen.appendBodyWithFixups(section_body);
                const inst_data = zir_datas[section_body[section_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (args.section_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.section_ref));
            }
            if (cc_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, cc_body));
                astgen.appendBodyWithFixups(cc_body);
                const inst_data = zir_datas[cc_body[cc_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (args.cc_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.cc_ref));
            }
            if (ret_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, ret_body));
                astgen.appendBodyWithFixups(ret_body);
                const inst_data = zir_datas[ret_body[ret_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (ret_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(ret_ref));
            }

            if (args.noalias_bits != 0) {
                astgen.extra.appendAssumeCapacity(args.noalias_bits);
            }

            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(src_locs);

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
            return indexToRef(new_index);
        } else {
            try astgen.extra.ensureUnusedCapacity(
                gpa,
                @typeInfo(Zir.Inst.Func).Struct.fields.len + 1 +
                    fancyFnExprExtraLen(astgen, ret_body, ret_ref) +
                    body_len + src_locs.len,
            );

            const ret_body_len = if (ret_body.len != 0)
                countBodyLenAfterFixups(astgen, ret_body)
            else
                @boolToInt(ret_ref != .none);

            const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.Func{
                .param_block = args.param_block,
                .ret_body_len = ret_body_len,
                .body_len = body_len,
            });
            const zir_datas = astgen.instructions.items(.data);
            if (ret_body.len != 0) {
                astgen.appendBodyWithFixups(ret_body);

                const inst_data = zir_datas[ret_body[ret_body.len - 1]].@"break";
                astgen.extra.items[inst_data.payload_index] = new_index;
            } else if (ret_ref != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(ret_ref));
            }
            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(src_locs);

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
            return indexToRef(new_index);
        }
    }

    fn fancyFnExprExtraLen(astgen: *AstGen, body: []Zir.Inst.Index, ref: Zir.Inst.Ref) u32 {
        // In the case of non-empty body, there is one for the body length,
        // and then one for each instruction.
        return countBodyLenAfterFixups(astgen, body) + @boolToInt(ref != .none);
    }

    fn addVar(gz: *GenZir, args: struct {
        align_inst: Zir.Inst.Ref,
        lib_name: u32,
        var_type: Zir.Inst.Ref,
        init: Zir.Inst.Ref,
        is_extern: bool,
        is_threadlocal: bool,
    }) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);

        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.ExtendedVar).Struct.fields.len +
                @boolToInt(args.lib_name != 0) +
                @boolToInt(args.align_inst != .none) +
                @boolToInt(args.init != .none),
        );
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.ExtendedVar{
            .var_type = args.var_type,
        });
        if (args.lib_name != 0) {
            astgen.extra.appendAssumeCapacity(args.lib_name);
        }
        if (args.align_inst != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.align_inst));
        }
        if (args.init != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.init));
        }

        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .variable,
                .small = @bitCast(u16, Zir.Inst.ExtendedVar.Small{
                    .has_lib_name = args.lib_name != 0,
                    .has_align = args.align_inst != .none,
                    .has_init = args.init != .none,
                    .is_extern = args.is_extern,
                    .is_threadlocal = args.is_threadlocal,
                }),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
    }

    /// Note that this returns a `Zir.Inst.Index` not a ref.
    /// Leaves the `payload_index` field undefined.
    fn addBoolBr(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        lhs: Zir.Inst.Ref,
    ) !Zir.Inst.Index {
        assert(lhs != .none);
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .bool_br = .{
                .lhs = lhs,
                .payload_index = undefined,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
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

        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .int_big,
            .data = .{ .str = .{
                .start = @intCast(u32, astgen.string_bytes.items.len),
                .len = @intCast(u32, limbs.len),
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        astgen.string_bytes.appendSliceAssumeCapacity(mem.sliceAsBytes(limbs));
        return indexToRef(new_index);
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
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
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
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(src_node),
                .payload_index = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
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
        name: u32,
        first_doc_comment: ?Ast.TokenIndex,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        const param_body = param_gz.instructionsSlice();
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Param).Struct.fields.len +
            param_body.len);

        const doc_comment_index = if (first_doc_comment) |first|
            try gz.astgen.docCommentAsStringFromFirst(abs_tok_index, first)
        else
            0;

        const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Param{
            .name = name,
            .doc_comment = doc_comment_index,
            .body_len = @intCast(u32, param_body.len),
        });
        gz.astgen.extra.appendSliceAssumeCapacity(param_body);
        param_gz.unstack();

        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
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
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
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
        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = @intCast(u16, operands.len),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        astgen.appendRefsAssumeCapacity(operands);
        return indexToRef(new_index);
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
        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = @intCast(u16, trailing_len),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
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
        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
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
        str_index: u32,
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
                .operand = if (cond == .if_of_error_type) cond.if_of_error_type else .none,
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
    ) !Zir.Inst.Index {
        return gz.addAsIndex(.{
            .tag = .restore_err_ret_index,
            .data = .{ .restore_err_ret_index = .{
                .block = switch (bt) {
                    .ret => .none,
                    .block => |b| Zir.indexToRef(b),
                },
                .operand = if (cond == .if_non_error) cond.if_non_error else .none,
            } },
        });
    }

    fn addBreak(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const extra: Zir.Inst.Break = .{
            .block_inst = block_inst,
            .operand_src_node = Zir.Inst.Break.no_src_node,
        };
        const payload_index = try gz.astgen.addExtra(extra);
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .@"break" = .{
                .operand = operand,
                .payload_index = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn makeBreak(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const extra: Zir.Inst.Break = .{
            .block_inst = block_inst,
            .operand_src_node = Zir.Inst.Break.no_src_node,
        };
        const payload_index = try gz.astgen.addExtra(extra);
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .@"break" = .{
                .operand = operand,
                .payload_index = payload_index,
            } },
        });
        return new_index;
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
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const extra: Zir.Inst.Break = .{
            .block_inst = block_inst,
            .operand_src_node = gz.nodeIndexToRelative(operand_src_node),
        };
        const payload_index = try gz.astgen.addExtra(extra);
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .@"break" = .{
                .operand = operand,
                .payload_index = payload_index,
            } },
        });
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
        const gpa = gz.astgen.gpa;
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const extra: Zir.Inst.Break = .{
            .block_inst = block_inst,
            .operand_src_node = gz.nodeIndexToRelative(operand_src_node),
        };
        const payload_index = try gz.astgen.addExtra(extra);
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .@"break" = .{
                .operand = operand,
                .payload_index = payload_index,
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
                .operand = @bitCast(u32, gz.nodeIndexToRelative(src_node)),
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
                @as(usize, @boolToInt(args.type_inst != .none)) +
                @as(usize, @boolToInt(args.align_inst != .none)),
        );
        const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.AllocExtended{
            .src_node = gz.nodeIndexToRelative(args.node),
        });
        if (args.type_inst != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.type_inst));
        }
        if (args.align_inst != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.align_inst));
        }

        const has_type: u4 = @boolToInt(args.type_inst != .none);
        const has_align: u4 = @boolToInt(args.align_inst != .none);
        const is_const: u4 = @boolToInt(args.is_const);
        const is_comptime: u4 = @boolToInt(args.is_comptime);
        const small: u16 = has_type | (has_align << 1) | (is_const << 2) | (is_comptime << 3);

        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .alloc,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
    }

    fn addAsm(
        gz: *GenZir,
        args: struct {
            tag: Zir.Inst.Extended,
            /// Absolute node index. This function does the conversion to offset from Decl.
            node: Ast.Node.Index,
            asm_source: u32,
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
        const small: u16 = @intCast(u16, args.outputs.len) |
            @intCast(u16, args.inputs.len << 5) |
            @intCast(u16, args.clobbers.len << 10) |
            (@as(u16, @boolToInt(args.is_volatile)) << 15);

        const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = args.tag,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return indexToRef(new_index);
    }

    /// Note that this returns a `Zir.Inst.Index` not a ref.
    /// Does *not* append the block instruction to the scope.
    /// Leaves the `payload_index` field undefined.
    fn makeBlockInst(gz: *GenZir, tag: Zir.Inst.Tag, node: Ast.Node.Index) !Zir.Inst.Index {
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
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
        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
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
        fields_len: u32,
        decls_len: u32,
        backing_int_ref: Zir.Inst.Ref,
        backing_int_body_len: u32,
        layout: std.builtin.Type.ContainerLayout,
        known_non_opv: bool,
        known_comptime_only: bool,
        is_tuple: bool,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try astgen.extra.ensureUnusedCapacity(gpa, 6);
        const payload_index = @intCast(u32, astgen.extra.items.len);

        if (args.src_node != 0) {
            const node_offset = gz.nodeIndexToRelative(args.src_node);
            astgen.extra.appendAssumeCapacity(@bitCast(u32, node_offset));
        }
        if (args.fields_len != 0) {
            astgen.extra.appendAssumeCapacity(args.fields_len);
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        if (args.backing_int_ref != .none) {
            astgen.extra.appendAssumeCapacity(args.backing_int_body_len);
            if (args.backing_int_body_len == 0) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.backing_int_ref));
            }
        }
        astgen.instructions.set(inst, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .struct_decl,
                .small = @bitCast(u16, Zir.Inst.StructDecl.Small{
                    .has_src_node = args.src_node != 0,
                    .has_fields_len = args.fields_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .has_backing_int = args.backing_int_ref != .none,
                    .known_non_opv = args.known_non_opv,
                    .known_comptime_only = args.known_comptime_only,
                    .is_tuple = args.is_tuple,
                    .name_strategy = gz.anon_name_strategy,
                    .layout = args.layout,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn setUnion(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        tag_type: Zir.Inst.Ref,
        body_len: u32,
        fields_len: u32,
        decls_len: u32,
        layout: std.builtin.Type.ContainerLayout,
        auto_enum_tag: bool,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try astgen.extra.ensureUnusedCapacity(gpa, 5);
        const payload_index = @intCast(u32, astgen.extra.items.len);

        if (args.src_node != 0) {
            const node_offset = gz.nodeIndexToRelative(args.src_node);
            astgen.extra.appendAssumeCapacity(@bitCast(u32, node_offset));
        }
        if (args.tag_type != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.tag_type));
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
        astgen.instructions.set(inst, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .union_decl,
                .small = @bitCast(u16, Zir.Inst.UnionDecl.Small{
                    .has_src_node = args.src_node != 0,
                    .has_tag_type = args.tag_type != .none,
                    .has_body_len = args.body_len != 0,
                    .has_fields_len = args.fields_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .name_strategy = gz.anon_name_strategy,
                    .layout = args.layout,
                    .auto_enum_tag = args.auto_enum_tag,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn setEnum(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        tag_type: Zir.Inst.Ref,
        body_len: u32,
        fields_len: u32,
        decls_len: u32,
        nonexhaustive: bool,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try astgen.extra.ensureUnusedCapacity(gpa, 5);
        const payload_index = @intCast(u32, astgen.extra.items.len);

        if (args.src_node != 0) {
            const node_offset = gz.nodeIndexToRelative(args.src_node);
            astgen.extra.appendAssumeCapacity(@bitCast(u32, node_offset));
        }
        if (args.tag_type != .none) {
            astgen.extra.appendAssumeCapacity(@enumToInt(args.tag_type));
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
        astgen.instructions.set(inst, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .enum_decl,
                .small = @bitCast(u16, Zir.Inst.EnumDecl.Small{
                    .has_src_node = args.src_node != 0,
                    .has_tag_type = args.tag_type != .none,
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
        decls_len: u32,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try astgen.extra.ensureUnusedCapacity(gpa, 2);
        const payload_index = @intCast(u32, astgen.extra.items.len);

        if (args.src_node != 0) {
            const node_offset = gz.nodeIndexToRelative(args.src_node);
            astgen.extra.appendAssumeCapacity(@bitCast(u32, node_offset));
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        astgen.instructions.set(inst, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .opaque_decl,
                .small = @bitCast(u16, Zir.Inst.OpaqueDecl.Small{
                    .has_src_node = args.src_node != 0,
                    .has_decls_len = args.decls_len != 0,
                    .name_strategy = gz.anon_name_strategy,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn add(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Ref {
        return indexToRef(try gz.addAsIndex(inst));
    }

    fn addAsIndex(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(inst);
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn reserveInstructionIndex(gz: *GenZir) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        gz.astgen.instructions.len += 1;
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn addRet(gz: *GenZir, ri: ResultInfo, operand: Zir.Inst.Ref, node: Ast.Node.Index) !void {
        switch (ri.rl) {
            .ptr => |ptr_res| _ = try gz.addUnNode(.ret_load, ptr_res.inst, node),
            .ty => _ = try gz.addUnNode(.ret_node, operand, node),
            else => unreachable,
        }
    }

    fn addNamespaceCaptures(gz: *GenZir, namespace: *Scope.Namespace) !void {
        if (namespace.captures.count() > 0) {
            try gz.instructions.ensureUnusedCapacity(gz.astgen.gpa, namespace.captures.count());
            for (namespace.captures.values()) |capture| {
                gz.instructions.appendAssumeCapacity(capture);
            }
        }
    }

    fn addDbgVar(gz: *GenZir, tag: Zir.Inst.Tag, name: u32, inst: Zir.Inst.Ref) !void {
        if (gz.is_comptime) return;

        _ = try gz.add(.{ .tag = tag, .data = .{
            .str_op = .{
                .str = name,
                .operand = inst,
            },
        } });
    }

    fn addDbgBlockBegin(gz: *GenZir) !void {
        if (gz.is_comptime) return;

        _ = try gz.add(.{ .tag = .dbg_block_begin, .data = undefined });
    }

    fn addDbgBlockEnd(gz: *GenZir) !void {
        if (gz.is_comptime) return;
        const gpa = gz.astgen.gpa;

        const tags = gz.astgen.instructions.items(.tag);
        const last_inst = gz.instructions.items[gz.instructions.items.len - 1];
        // remove dbg_block_begin immediately followed by dbg_block_end
        if (tags[last_inst] == .dbg_block_begin) {
            _ = gz.instructions.pop();
            return;
        }

        const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
        try gz.astgen.instructions.append(gpa, .{ .tag = .dbg_block_end, .data = undefined });
        try gz.instructions.append(gpa, new_index);
    }
};

/// This can only be for short-lived references; the memory becomes invalidated
/// when another string is added.
fn nullTerminatedString(astgen: AstGen, index: usize) [*:0]const u8 {
    return @ptrCast([*:0]const u8, astgen.string_bytes.items.ptr) + index;
}

/// Local variables shadowing detection, including function parameters.
fn detectLocalShadowing(
    astgen: *AstGen,
    scope: *Scope,
    ident_name: u32,
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
        .namespace, .enum_namespace => {
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
    var decl_count: u32 = 0;
    for (members) |member_node| {
        const name_token = switch (node_tags[member_node]) {
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => blk: {
                decl_count += 1;
                break :blk main_tokens[member_node] + 1;
            },

            .fn_decl => blk: {
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

            .@"comptime", .@"usingnamespace", .test_decl => {
                decl_count += 1;
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
            .namespace, .enum_namespace => s = s.cast(Scope.Namespace).?.parent,
            .gen_zir => s = s.cast(GenZir).?.parent,
            .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
            .top => break,
        };
        gop.value_ptr.* = member_node;
    }
    return decl_count;
}

fn isInferred(astgen: *AstGen, ref: Zir.Inst.Ref) bool {
    const inst = refToIndex(ref) orelse return false;
    const zir_tags = astgen.instructions.items(.tag);
    return switch (zir_tags[inst]) {
        .alloc_inferred,
        .alloc_inferred_mut,
        .alloc_inferred_comptime,
        .alloc_inferred_comptime_mut,
        => true,

        .extended => {
            const zir_data = astgen.instructions.items(.data);
            if (zir_data[inst].extended.opcode != .alloc) return false;
            const small = @bitCast(Zir.Inst.AllocExtended.Small, zir_data[inst].extended.small);
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
    list.appendAssumeCapacity(body_inst);
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
    return @intCast(u32, count);
}

fn emitDbgStmt(gz: *GenZir, lc: LineColumn) !void {
    if (gz.is_comptime) return;

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

    if (token_tags[parse_err.token + @boolToInt(parse_err.token_is_prev)] == .invalid) {
        const tok = parse_err.token + @boolToInt(parse_err.token_is_prev);
        const bad_off = @intCast(u32, tree.tokenSlice(parse_err.token + @boolToInt(parse_err.token_is_prev)).len);
        const byte_abs = token_starts[parse_err.token + @boolToInt(parse_err.token_is_prev)] + bad_off;
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
