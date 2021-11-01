//! Semantic analysis of ZIR instructions.
//! Shared to every Block. Stored on the stack.
//! State used for compiling a ZIR into AIR.
//! Transforms untyped ZIR instructions into semantically-analyzed AIR instructions.
//! Does type checking, comptime control flow, and safety-check generation.
//! This is the the heart of the Zig compiler.

mod: *Module,
/// Alias to `mod.gpa`.
gpa: *Allocator,
/// Points to the temporary arena allocator of the Sema.
/// This arena will be cleared when the sema is destroyed.
arena: *Allocator,
/// Points to the arena allocator for the owner_decl.
/// This arena will persist until the decl is invalidated.
perm_arena: *Allocator,
code: Zir,
air_instructions: std.MultiArrayList(Air.Inst) = .{},
air_extra: std.ArrayListUnmanaged(u32) = .{},
air_values: std.ArrayListUnmanaged(Value) = .{},
/// Maps ZIR to AIR.
inst_map: InstMap = .{},
/// When analyzing an inline function call, owner_decl is the Decl of the caller
/// and `src_decl` of `Block` is the `Decl` of the callee.
/// This `Decl` owns the arena memory of this `Sema`.
owner_decl: *Decl,
/// For an inline or comptime function call, this will be the root parent function
/// which contains the callsite. Corresponds to `owner_decl`.
owner_func: ?*Module.Fn,
/// The function this ZIR code is the body of, according to the source code.
/// This starts out the same as `owner_func` and then diverges in the case of
/// an inline or comptime function call.
func: ?*Module.Fn,
/// When semantic analysis needs to know the return type of the function whose body
/// is being analyzed, this `Type` should be used instead of going through `func`.
/// This will correctly handle the case of a comptime/inline function call of a
/// generic function which uses a type expression for the return type.
/// The type will be `void` in the case that `func` is `null`.
fn_ret_ty: Type,
branch_quota: u32 = 1000,
branch_count: u32 = 0,
/// This field is updated when a new source location becomes active, so that
/// instructions which do not have explicitly mapped source locations still have
/// access to the source location set by the previous instruction which did
/// contain a mapped source location.
src: LazySrcLoc = .{ .token_offset = 0 },
decl_val_table: std.AutoHashMapUnmanaged(*Decl, Air.Inst.Ref) = .{},
/// When doing a generic function instantiation, this array collects a
/// `Value` object for each parameter that is comptime known and thus elided
/// from the generated function. This memory is allocated by a parent `Sema` and
/// owned by the values arena of the Sema owner_decl.
comptime_args: []TypedValue = &.{},
/// Marks the function instruction that `comptime_args` applies to so that we
/// don't accidentally apply it to a function prototype which is used in the
/// type expression of a generic function parameter.
comptime_args_fn_inst: Zir.Inst.Index = 0,
/// When `comptime_args` is provided, this field is also provided. It was used as
/// the key in the `monomorphed_funcs` set. The `func` instruction is supposed
/// to use this instead of allocating a fresh one. This avoids an unnecessary
/// extra hash table lookup in the `monomorphed_funcs` set.
/// Sema will set this to null when it takes ownership.
preallocated_new_func: ?*Module.Fn = null,

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.sema);

const Sema = @This();
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Air = @import("Air.zig");
const Zir = @import("Zir.zig");
const Module = @import("Module.zig");
const trace = @import("tracy.zig").trace;
const Namespace = Module.Namespace;
const CompileError = Module.CompileError;
const SemaError = Module.SemaError;
const Decl = Module.Decl;
const CaptureScope = Module.CaptureScope;
const WipCaptureScope = Module.WipCaptureScope;
const LazySrcLoc = Module.LazySrcLoc;
const RangeSet = @import("RangeSet.zig");
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const crash_report = @import("crash_report.zig");

pub const InstMap = std.AutoHashMapUnmanaged(Zir.Inst.Index, Air.Inst.Ref);

/// This is the context needed to semantically analyze ZIR instructions and
/// produce AIR instructions.
/// This is a temporary structure stored on the stack; references to it are valid only
/// during semantic analysis of the block.
pub const Block = struct {
    parent: ?*Block,
    /// Shared among all child blocks.
    sema: *Sema,
    /// This Decl is the Decl according to the Zig source code corresponding to this Block.
    /// This can vary during inline or comptime function calls. See `Sema.owner_decl`
    /// for the one that will be the same for all Block instances.
    src_decl: *Decl,
    /// The namespace to use for lookups from this source block
    /// When analyzing fields, this is different from src_decl.src_namepsace.
    namespace: *Namespace,
    /// The AIR instructions generated for this block.
    instructions: std.ArrayListUnmanaged(Air.Inst.Index),
    // `param` instructions are collected here to be used by the `func` instruction.
    params: std.ArrayListUnmanaged(Param) = .{},

    wip_capture_scope: *CaptureScope,

    label: ?*Label = null,
    inlining: ?*Inlining,
    /// If runtime_index is not 0 then one of these is guaranteed to be non null.
    runtime_cond: ?LazySrcLoc = null,
    runtime_loop: ?LazySrcLoc = null,
    /// Non zero if a non-inline loop or a runtime conditional have been encountered.
    /// Stores to to comptime variables are only allowed when var.runtime_index <= runtime_index.
    runtime_index: u32 = 0,

    is_comptime: bool,

    /// when null, it is determined by build mode, changed by @setRuntimeSafety
    want_safety: ?bool = null,

    c_import_buf: ?*std.ArrayList(u8) = null,

    const Param = struct {
        /// `noreturn` means `anytype`.
        ty: Type,
        is_comptime: bool,
    };

    /// This `Block` maps a block ZIR instruction to the corresponding
    /// AIR instruction for break instruction analysis.
    pub const Label = struct {
        zir_block: Zir.Inst.Index,
        merges: Merges,
    };

    /// This `Block` indicates that an inline function call is happening
    /// and return instructions should be analyzed as a break instruction
    /// to this AIR block instruction.
    /// It is shared among all the blocks in an inline or comptime called
    /// function.
    pub const Inlining = struct {
        comptime_result: Air.Inst.Ref,
        merges: Merges,
    };

    pub const Merges = struct {
        block_inst: Air.Inst.Index,
        /// Separate array list from break_inst_list so that it can be passed directly
        /// to resolvePeerTypes.
        results: std.ArrayListUnmanaged(Air.Inst.Ref),
        /// Keeps track of the break instructions so that the operand can be replaced
        /// if we need to add type coercion at the end of block analysis.
        /// Same indexes, capacity, length as `results`.
        br_list: std.ArrayListUnmanaged(Air.Inst.Index),
    };

    /// For debugging purposes.
    pub fn dump(block: *Block, mod: Module) void {
        Zir.dumpBlock(mod, block);
    }

    pub fn makeSubBlock(parent: *Block) Block {
        return .{
            .parent = parent,
            .sema = parent.sema,
            .src_decl = parent.src_decl,
            .namespace = parent.namespace,
            .instructions = .{},
            .wip_capture_scope = parent.wip_capture_scope,
            .label = null,
            .inlining = parent.inlining,
            .is_comptime = parent.is_comptime,
            .runtime_cond = parent.runtime_cond,
            .runtime_loop = parent.runtime_loop,
            .runtime_index = parent.runtime_index,
            .want_safety = parent.want_safety,
            .c_import_buf = parent.c_import_buf,
        };
    }

    pub fn wantSafety(block: *const Block) bool {
        return block.want_safety orelse switch (block.sema.mod.optimizeMode()) {
            .Debug => true,
            .ReleaseSafe => true,
            .ReleaseFast => false,
            .ReleaseSmall => false,
        };
    }

    pub fn getFileScope(block: *Block) *Module.File {
        return block.namespace.file_scope;
    }

    pub fn addTy(
        block: *Block,
        tag: Air.Inst.Tag,
        ty: Type,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty = ty },
        });
    }

    pub fn addTyOp(
        block: *Block,
        tag: Air.Inst.Tag,
        ty: Type,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty_op = .{
                .ty = try block.sema.addType(ty),
                .operand = operand,
            } },
        });
    }

    pub fn addBitCast(block: *Block, ty: Type, operand: Air.Inst.Ref) Allocator.Error!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .bitcast,
            .data = .{ .ty_op = .{
                .ty = try block.sema.addType(ty),
                .operand = operand,
            } },
        });
    }

    pub fn addNoOp(block: *Block, tag: Air.Inst.Tag) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .no_op = {} },
        });
    }

    pub fn addUnOp(
        block: *Block,
        tag: Air.Inst.Tag,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .un_op = operand },
        });
    }

    pub fn addBr(
        block: *Block,
        target_block: Air.Inst.Index,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = target_block,
                .operand = operand,
            } },
        });
    }

    pub fn addBinOp(
        block: *Block,
        tag: Air.Inst.Tag,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .bin_op = .{
                .lhs = lhs,
                .rhs = rhs,
            } },
        });
    }

    pub fn addArg(block: *Block, ty: Type, name: u32) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .arg,
            .data = .{ .ty_str = .{
                .ty = try block.sema.addType(ty),
                .str = name,
            } },
        });
    }

    pub fn addStructFieldPtr(
        block: *Block,
        struct_ptr: Air.Inst.Ref,
        field_index: u32,
        ptr_field_ty: Type,
    ) !Air.Inst.Ref {
        const ty = try block.sema.addType(ptr_field_ty);
        const tag: Air.Inst.Tag = switch (field_index) {
            0 => .struct_field_ptr_index_0,
            1 => .struct_field_ptr_index_1,
            2 => .struct_field_ptr_index_2,
            3 => .struct_field_ptr_index_3,
            else => {
                return block.addInst(.{
                    .tag = .struct_field_ptr,
                    .data = .{ .ty_pl = .{
                        .ty = ty,
                        .payload = try block.sema.addExtra(Air.StructField{
                            .struct_operand = struct_ptr,
                            .field_index = field_index,
                        }),
                    } },
                });
            },
        };
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty_op = .{
                .ty = ty,
                .operand = struct_ptr,
            } },
        });
    }

    pub fn addStructFieldVal(
        block: *Block,
        struct_val: Air.Inst.Ref,
        field_index: u32,
        field_ty: Type,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .struct_field_val,
            .data = .{ .ty_pl = .{
                .ty = try block.sema.addType(field_ty),
                .payload = try block.sema.addExtra(Air.StructField{
                    .struct_operand = struct_val,
                    .field_index = field_index,
                }),
            } },
        });
    }

    pub fn addSliceElemPtr(
        block: *Block,
        slice: Air.Inst.Ref,
        elem_index: Air.Inst.Ref,
        elem_ptr_ty: Type,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .slice_elem_ptr,
            .data = .{ .ty_pl = .{
                .ty = try block.sema.addType(elem_ptr_ty),
                .payload = try block.sema.addExtra(Air.Bin{
                    .lhs = slice,
                    .rhs = elem_index,
                }),
            } },
        });
    }

    pub fn addPtrElemPtr(
        block: *Block,
        array_ptr: Air.Inst.Ref,
        elem_index: Air.Inst.Ref,
        elem_ptr_ty: Type,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .ptr_elem_ptr,
            .data = .{ .ty_pl = .{
                .ty = try block.sema.addType(elem_ptr_ty),
                .payload = try block.sema.addExtra(Air.Bin{
                    .lhs = array_ptr,
                    .rhs = elem_index,
                }),
            } },
        });
    }

    pub fn addInst(block: *Block, inst: Air.Inst) error{OutOfMemory}!Air.Inst.Ref {
        return Air.indexToRef(try block.addInstAsIndex(inst));
    }

    pub fn addInstAsIndex(block: *Block, inst: Air.Inst) error{OutOfMemory}!Air.Inst.Index {
        const sema = block.sema;
        const gpa = sema.gpa;

        try sema.air_instructions.ensureUnusedCapacity(gpa, 1);
        try block.instructions.ensureUnusedCapacity(gpa, 1);

        const result_index = @intCast(Air.Inst.Index, sema.air_instructions.len);
        sema.air_instructions.appendAssumeCapacity(inst);
        block.instructions.appendAssumeCapacity(result_index);
        return result_index;
    }

    fn addUnreachable(block: *Block, src: LazySrcLoc, safety_check: bool) !void {
        if (safety_check and block.wantSafety()) {
            _ = try block.sema.safetyPanic(block, src, .unreach);
        } else {
            _ = try block.addNoOp(.unreach);
        }
    }

    pub fn startAnonDecl(block: *Block) !WipAnonDecl {
        return WipAnonDecl{
            .block = block,
            .new_decl_arena = std.heap.ArenaAllocator.init(block.sema.gpa),
            .finished = false,
        };
    }

    pub const WipAnonDecl = struct {
        block: *Block,
        new_decl_arena: std.heap.ArenaAllocator,
        finished: bool,

        pub fn arena(wad: *WipAnonDecl) *Allocator {
            return &wad.new_decl_arena.allocator;
        }

        pub fn deinit(wad: *WipAnonDecl) void {
            if (!wad.finished) {
                wad.new_decl_arena.deinit();
            }
            wad.* = undefined;
        }

        pub fn finish(wad: *WipAnonDecl, ty: Type, val: Value) !*Decl {
            const new_decl = try wad.block.sema.mod.createAnonymousDecl(wad.block, .{
                .ty = ty,
                .val = val,
            });
            errdefer wad.block.sema.mod.abortAnonDecl(new_decl);
            try new_decl.finalizeNewArena(&wad.new_decl_arena);
            wad.finished = true;
            return new_decl;
        }
    };
};

pub fn deinit(sema: *Sema) void {
    const gpa = sema.gpa;
    sema.air_instructions.deinit(gpa);
    sema.air_extra.deinit(gpa);
    sema.air_values.deinit(gpa);
    sema.inst_map.deinit(gpa);
    sema.decl_val_table.deinit(gpa);
    sema.* = undefined;
}

/// Returns only the result from the body that is specified.
/// Only appropriate to call when it is determined at comptime that this body
/// has no peers.
fn resolveBody(sema: *Sema, block: *Block, body: []const Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const break_inst = try sema.analyzeBody(block, body);
    const operand_ref = sema.code.instructions.items(.data)[break_inst].@"break".operand;
    return sema.resolveInst(operand_ref);
}

/// ZIR instructions which are always `noreturn` return this. This matches the
/// return type of `analyzeBody` so that we can tail call them.
/// Only appropriate to return when the instruction is known to be NoReturn
/// solely based on the ZIR tag.
const always_noreturn: CompileError!Zir.Inst.Index = @as(Zir.Inst.Index, undefined);

/// This function is the main loop of `Sema` and it can be used in two different ways:
/// * The traditional way where there are N breaks out of the block and peer type
///   resolution is done on the break operands. In this case, the `Zir.Inst.Index`
///   part of the return value will be `undefined`, and callsites should ignore it,
///   finding the block result value via the block scope.
/// * The "flat" way. There is only 1 break out of the block, and it is with a `break_inline`
///   instruction. In this case, the `Zir.Inst.Index` part of the return value will be
///   the break instruction. This communicates both which block the break applies to, as
///   well as the operand. No block scope needs to be created for this strategy.
pub fn analyzeBody(
    sema: *Sema,
    block: *Block,
    body: []const Zir.Inst.Index,
) CompileError!Zir.Inst.Index {
    // No tracy calls here, to avoid interfering with the tail call mechanism.

    const parent_capture_scope = block.wip_capture_scope;

    var wip_captures = WipCaptureScope{
        .finalized = true,
        .scope = parent_capture_scope,
        .perm_arena = sema.perm_arena,
        .gpa = sema.gpa,
    };
    defer if (wip_captures.scope != parent_capture_scope) {
        wip_captures.deinit();
    };

    const map = &sema.inst_map;
    const tags = sema.code.instructions.items(.tag);
    const datas = sema.code.instructions.items(.data);

    var orig_captures: usize = parent_capture_scope.captures.count();

    var crash_info = crash_report.prepAnalyzeBody(sema, block, body);
    crash_info.push();
    defer crash_info.pop();

    // We use a while(true) loop here to avoid a redundant way of breaking out of
    // the loop. The only way to break out of the loop is with a `noreturn`
    // instruction.
    var i: usize = 0;
    const result = while (true) {
        crash_info.setBodyIndex(i);
        const inst = body[i];
        const air_inst: Air.Inst.Ref = switch (tags[inst]) {
            // zig fmt: off
            .alloc                        => try sema.zirAlloc(block, inst),
            .alloc_inferred               => try sema.zirAllocInferred(block, inst, Type.initTag(.inferred_alloc_const)),
            .alloc_inferred_mut           => try sema.zirAllocInferred(block, inst, Type.initTag(.inferred_alloc_mut)),
            .alloc_inferred_comptime      => try sema.zirAllocInferredComptime(inst),
            .alloc_mut                    => try sema.zirAllocMut(block, inst),
            .alloc_comptime               => try sema.zirAllocComptime(block, inst),
            .anyframe_type                => try sema.zirAnyframeType(block, inst),
            .array_cat                    => try sema.zirArrayCat(block, inst),
            .array_mul                    => try sema.zirArrayMul(block, inst),
            .array_type                   => try sema.zirArrayType(block, inst),
            .array_type_sentinel          => try sema.zirArrayTypeSentinel(block, inst),
            .vector_type                  => try sema.zirVectorType(block, inst),
            .as                           => try sema.zirAs(block, inst),
            .as_node                      => try sema.zirAsNode(block, inst),
            .bit_and                      => try sema.zirBitwise(block, inst, .bit_and),
            .bit_not                      => try sema.zirBitNot(block, inst),
            .bit_or                       => try sema.zirBitwise(block, inst, .bit_or),
            .bitcast                      => try sema.zirBitcast(block, inst),
            .suspend_block                => try sema.zirSuspendBlock(block, inst),
            .bool_not                     => try sema.zirBoolNot(block, inst),
            .bool_br_and                  => try sema.zirBoolBr(block, inst, false),
            .bool_br_or                   => try sema.zirBoolBr(block, inst, true),
            .c_import                     => try sema.zirCImport(block, inst),
            .call                         => try sema.zirCall(block, inst),
            .closure_get                  => try sema.zirClosureGet(block, inst),
            .cmp_lt                       => try sema.zirCmp(block, inst, .lt),
            .cmp_lte                      => try sema.zirCmp(block, inst, .lte),
            .cmp_eq                       => try sema.zirCmpEq(block, inst, .eq, .cmp_eq),
            .cmp_gte                      => try sema.zirCmp(block, inst, .gte),
            .cmp_gt                       => try sema.zirCmp(block, inst, .gt),
            .cmp_neq                      => try sema.zirCmpEq(block, inst, .neq, .cmp_neq),
            .coerce_result_ptr            => try sema.zirCoerceResultPtr(block, inst),
            .decl_ref                     => try sema.zirDeclRef(block, inst),
            .decl_val                     => try sema.zirDeclVal(block, inst),
            .load                         => try sema.zirLoad(block, inst),
            .elem_ptr                     => try sema.zirElemPtr(block, inst),
            .elem_ptr_node                => try sema.zirElemPtrNode(block, inst),
            .elem_ptr_imm                 => try sema.zirElemPtrImm(block, inst),
            .elem_val                     => try sema.zirElemVal(block, inst),
            .elem_val_node                => try sema.zirElemValNode(block, inst),
            .elem_type                    => try sema.zirElemType(block, inst),
            .enum_literal                 => try sema.zirEnumLiteral(block, inst),
            .enum_to_int                  => try sema.zirEnumToInt(block, inst),
            .int_to_enum                  => try sema.zirIntToEnum(block, inst),
            .err_union_code               => try sema.zirErrUnionCode(block, inst),
            .err_union_code_ptr           => try sema.zirErrUnionCodePtr(block, inst),
            .err_union_payload_safe       => try sema.zirErrUnionPayload(block, inst, true),
            .err_union_payload_safe_ptr   => try sema.zirErrUnionPayloadPtr(block, inst, true),
            .err_union_payload_unsafe     => try sema.zirErrUnionPayload(block, inst, false),
            .err_union_payload_unsafe_ptr => try sema.zirErrUnionPayloadPtr(block, inst, false),
            .error_union_type             => try sema.zirErrorUnionType(block, inst),
            .error_value                  => try sema.zirErrorValue(block, inst),
            .error_to_int                 => try sema.zirErrorToInt(block, inst),
            .int_to_error                 => try sema.zirIntToError(block, inst),
            .field_ptr                    => try sema.zirFieldPtr(block, inst),
            .field_ptr_named              => try sema.zirFieldPtrNamed(block, inst),
            .field_val                    => try sema.zirFieldVal(block, inst),
            .field_val_named              => try sema.zirFieldValNamed(block, inst),
            .field_call_bind              => try sema.zirFieldCallBind(block, inst),
            .field_call_bind_named        => try sema.zirFieldCallBindNamed(block, inst),
            .func                         => try sema.zirFunc(block, inst, false),
            .func_inferred                => try sema.zirFunc(block, inst, true),
            .import                       => try sema.zirImport(block, inst),
            .indexable_ptr_len            => try sema.zirIndexablePtrLen(block, inst),
            .int                          => try sema.zirInt(block, inst),
            .int_big                      => try sema.zirIntBig(block, inst),
            .float                        => try sema.zirFloat(block, inst),
            .float128                     => try sema.zirFloat128(block, inst),
            .int_type                     => try sema.zirIntType(block, inst),
            .is_non_err                   => try sema.zirIsNonErr(block, inst),
            .is_non_err_ptr               => try sema.zirIsNonErrPtr(block, inst),
            .is_non_null                  => try sema.zirIsNonNull(block, inst),
            .is_non_null_ptr              => try sema.zirIsNonNullPtr(block, inst),
            .merge_error_sets             => try sema.zirMergeErrorSets(block, inst),
            .negate                       => try sema.zirNegate(block, inst, .sub),
            .negate_wrap                  => try sema.zirNegate(block, inst, .subwrap),
            .optional_payload_safe        => try sema.zirOptionalPayload(block, inst, true),
            .optional_payload_safe_ptr    => try sema.zirOptionalPayloadPtr(block, inst, true),
            .optional_payload_unsafe      => try sema.zirOptionalPayload(block, inst, false),
            .optional_payload_unsafe_ptr  => try sema.zirOptionalPayloadPtr(block, inst, false),
            .optional_type                => try sema.zirOptionalType(block, inst),
            .ptr_type                     => try sema.zirPtrType(block, inst),
            .ptr_type_simple              => try sema.zirPtrTypeSimple(block, inst),
            .ref                          => try sema.zirRef(block, inst),
            .ret_err_value_code           => try sema.zirRetErrValueCode(block, inst),
            .shr                          => try sema.zirShr(block, inst),
            .slice_end                    => try sema.zirSliceEnd(block, inst),
            .slice_sentinel               => try sema.zirSliceSentinel(block, inst),
            .slice_start                  => try sema.zirSliceStart(block, inst),
            .str                          => try sema.zirStr(block, inst),
            .switch_block                 => try sema.zirSwitchBlock(block, inst),
            .switch_cond                  => try sema.zirSwitchCond(block, inst, false),
            .switch_cond_ref              => try sema.zirSwitchCond(block, inst, true),
            .switch_capture               => try sema.zirSwitchCapture(block, inst, false, false),
            .switch_capture_ref           => try sema.zirSwitchCapture(block, inst, false, true),
            .switch_capture_multi         => try sema.zirSwitchCapture(block, inst, true, false),
            .switch_capture_multi_ref     => try sema.zirSwitchCapture(block, inst, true, true),
            .switch_capture_else          => try sema.zirSwitchCaptureElse(block, inst, false),
            .switch_capture_else_ref      => try sema.zirSwitchCaptureElse(block, inst, true),
            .type_info                    => try sema.zirTypeInfo(block, inst),
            .size_of                      => try sema.zirSizeOf(block, inst),
            .bit_size_of                  => try sema.zirBitSizeOf(block, inst),
            .typeof                       => try sema.zirTypeof(block, inst),
            .log2_int_type                => try sema.zirLog2IntType(block, inst),
            .typeof_log2_int_type         => try sema.zirTypeofLog2IntType(block, inst),
            .xor                          => try sema.zirBitwise(block, inst, .xor),
            .struct_init_empty            => try sema.zirStructInitEmpty(block, inst),
            .struct_init                  => try sema.zirStructInit(block, inst, false),
            .struct_init_ref              => try sema.zirStructInit(block, inst, true),
            .struct_init_anon             => try sema.zirStructInitAnon(block, inst, false),
            .struct_init_anon_ref         => try sema.zirStructInitAnon(block, inst, true),
            .array_init                   => try sema.zirArrayInit(block, inst, false),
            .array_init_ref               => try sema.zirArrayInit(block, inst, true),
            .array_init_anon              => try sema.zirArrayInitAnon(block, inst, false),
            .array_init_anon_ref          => try sema.zirArrayInitAnon(block, inst, true),
            .union_init_ptr               => try sema.zirUnionInitPtr(block, inst),
            .field_type                   => try sema.zirFieldType(block, inst),
            .field_type_ref               => try sema.zirFieldTypeRef(block, inst),
            .ptr_to_int                   => try sema.zirPtrToInt(block, inst),
            .align_of                     => try sema.zirAlignOf(block, inst),
            .bool_to_int                  => try sema.zirBoolToInt(block, inst),
            .embed_file                   => try sema.zirEmbedFile(block, inst),
            .error_name                   => try sema.zirErrorName(block, inst),
            .tag_name                     => try sema.zirTagName(block, inst),
            .reify                        => try sema.zirReify(block, inst),
            .type_name                    => try sema.zirTypeName(block, inst),
            .frame_type                   => try sema.zirFrameType(block, inst),
            .frame_size                   => try sema.zirFrameSize(block, inst),
            .float_to_int                 => try sema.zirFloatToInt(block, inst),
            .int_to_float                 => try sema.zirIntToFloat(block, inst),
            .int_to_ptr                   => try sema.zirIntToPtr(block, inst),
            .float_cast                   => try sema.zirFloatCast(block, inst),
            .int_cast                     => try sema.zirIntCast(block, inst),
            .err_set_cast                 => try sema.zirErrSetCast(block, inst),
            .ptr_cast                     => try sema.zirPtrCast(block, inst),
            .truncate                     => try sema.zirTruncate(block, inst),
            .align_cast                   => try sema.zirAlignCast(block, inst),
            .has_decl                     => try sema.zirHasDecl(block, inst),
            .has_field                    => try sema.zirHasField(block, inst),
            .clz                          => try sema.zirClz(block, inst),
            .ctz                          => try sema.zirCtz(block, inst),
            .pop_count                    => try sema.zirPopCount(block, inst),
            .byte_swap                    => try sema.zirByteSwap(block, inst),
            .bit_reverse                  => try sema.zirBitReverse(block, inst),
            .shr_exact                    => try sema.zirShrExact(block, inst),
            .bit_offset_of                => try sema.zirBitOffsetOf(block, inst),
            .offset_of                    => try sema.zirOffsetOf(block, inst),
            .cmpxchg_strong               => try sema.zirCmpxchg(block, inst, .cmpxchg_strong),
            .cmpxchg_weak                 => try sema.zirCmpxchg(block, inst, .cmpxchg_weak),
            .splat                        => try sema.zirSplat(block, inst),
            .reduce                       => try sema.zirReduce(block, inst),
            .shuffle                      => try sema.zirShuffle(block, inst),
            .select                       => try sema.zirSelect(block, inst),
            .atomic_load                  => try sema.zirAtomicLoad(block, inst),
            .atomic_rmw                   => try sema.zirAtomicRmw(block, inst),
            .mul_add                      => try sema.zirMulAdd(block, inst),
            .builtin_call                 => try sema.zirBuiltinCall(block, inst),
            .field_ptr_type               => try sema.zirFieldPtrType(block, inst),
            .field_parent_ptr             => try sema.zirFieldParentPtr(block, inst),
            .builtin_async_call           => try sema.zirBuiltinAsyncCall(block, inst),
            .@"resume"                    => try sema.zirResume(block, inst),
            .@"await"                     => try sema.zirAwait(block, inst, false),
            .await_nosuspend              => try sema.zirAwait(block, inst, true),
            .extended                     => try sema.zirExtended(block, inst),

            .sqrt  => try sema.zirUnaryMath(block, inst),
            .sin   => try sema.zirUnaryMath(block, inst),
            .cos   => try sema.zirUnaryMath(block, inst),
            .exp   => try sema.zirUnaryMath(block, inst),
            .exp2  => try sema.zirUnaryMath(block, inst),
            .log   => try sema.zirUnaryMath(block, inst),
            .log2  => try sema.zirUnaryMath(block, inst),
            .log10 => try sema.zirUnaryMath(block, inst),
            .fabs  => try sema.zirUnaryMath(block, inst),
            .floor => try sema.zirUnaryMath(block, inst),
            .ceil  => try sema.zirUnaryMath(block, inst),
            .trunc => try sema.zirUnaryMath(block, inst),
            .round => try sema.zirUnaryMath(block, inst),

            .error_set_decl      => try sema.zirErrorSetDecl(block, inst, .parent),
            .error_set_decl_anon => try sema.zirErrorSetDecl(block, inst, .anon),
            .error_set_decl_func => try sema.zirErrorSetDecl(block, inst, .func),

            .add       => try sema.zirArithmetic(block, inst, .add),
            .addwrap   => try sema.zirArithmetic(block, inst, .addwrap),
            .add_sat   => try sema.zirArithmetic(block, inst, .add_sat),
            .div       => try sema.zirArithmetic(block, inst, .div),
            .div_exact => try sema.zirArithmetic(block, inst, .div_exact),
            .div_floor => try sema.zirArithmetic(block, inst, .div_floor),
            .div_trunc => try sema.zirArithmetic(block, inst, .div_trunc),
            .mod_rem   => try sema.zirArithmetic(block, inst, .mod_rem),
            .mod       => try sema.zirArithmetic(block, inst, .mod),
            .rem       => try sema.zirArithmetic(block, inst, .rem),
            .mul       => try sema.zirArithmetic(block, inst, .mul),
            .mulwrap   => try sema.zirArithmetic(block, inst, .mulwrap),
            .mul_sat   => try sema.zirArithmetic(block, inst, .mul_sat),
            .sub       => try sema.zirArithmetic(block, inst, .sub),
            .subwrap   => try sema.zirArithmetic(block, inst, .subwrap),
            .sub_sat   => try sema.zirArithmetic(block, inst, .sub_sat),

            .maximum => try sema.zirMinMax(block, inst, .max),
            .minimum => try sema.zirMinMax(block, inst, .min),

            .shl       => try sema.zirShl(block, inst, .shl),
            .shl_exact => try sema.zirShl(block, inst, .shl_exact),
            .shl_sat   => try sema.zirShl(block, inst, .shl_sat),

            // Instructions that we know to *always* be noreturn based solely on their tag.
            // These functions match the return type of analyzeBody so that we can
            // tail call them here.
            .compile_error  => break sema.zirCompileError(block, inst),
            .ret_coerce     => break sema.zirRetCoerce(block, inst),
            .ret_node       => break sema.zirRetNode(block, inst),
            .ret_load       => break sema.zirRetLoad(block, inst),
            .ret_err_value  => break sema.zirRetErrValue(block, inst),
            .@"unreachable" => break sema.zirUnreachable(block, inst),
            .panic          => break sema.zirPanic(block, inst),
            // zig fmt: on

            // Instructions that we know can *never* be noreturn based solely on
            // their tag. We avoid needlessly checking if they are noreturn and
            // continue the loop.
            // We also know that they cannot be referenced later, so we avoid
            // putting them into the map.
            .breakpoint => {
                if (!block.is_comptime) {
                    _ = try block.addNoOp(.breakpoint);
                }
                i += 1;
                continue;
            },
            .fence => {
                try sema.zirFence(block, inst);
                i += 1;
                continue;
            },
            .dbg_stmt => {
                try sema.zirDbgStmt(block, inst);
                i += 1;
                continue;
            },
            .ensure_err_payload_void => {
                try sema.zirEnsureErrPayloadVoid(block, inst);
                i += 1;
                continue;
            },
            .ensure_result_non_error => {
                try sema.zirEnsureResultNonError(block, inst);
                i += 1;
                continue;
            },
            .ensure_result_used => {
                try sema.zirEnsureResultUsed(block, inst);
                i += 1;
                continue;
            },
            .set_eval_branch_quota => {
                try sema.zirSetEvalBranchQuota(block, inst);
                i += 1;
                continue;
            },
            .atomic_store => {
                try sema.zirAtomicStore(block, inst);
                i += 1;
                continue;
            },
            .store => {
                try sema.zirStore(block, inst);
                i += 1;
                continue;
            },
            .store_node => {
                try sema.zirStoreNode(block, inst);
                i += 1;
                continue;
            },
            .store_to_block_ptr => {
                try sema.zirStoreToBlockPtr(block, inst);
                i += 1;
                continue;
            },
            .store_to_inferred_ptr => {
                try sema.zirStoreToInferredPtr(block, inst);
                i += 1;
                continue;
            },
            .resolve_inferred_alloc => {
                try sema.zirResolveInferredAlloc(block, inst);
                i += 1;
                continue;
            },
            .validate_struct_init => {
                try sema.zirValidateStructInit(block, inst);
                i += 1;
                continue;
            },
            .validate_array_init => {
                try sema.zirValidateArrayInit(block, inst);
                i += 1;
                continue;
            },
            .@"export" => {
                try sema.zirExport(block, inst);
                i += 1;
                continue;
            },
            .export_value => {
                try sema.zirExportValue(block, inst);
                i += 1;
                continue;
            },
            .set_align_stack => {
                try sema.zirSetAlignStack(block, inst);
                i += 1;
                continue;
            },
            .set_cold => {
                try sema.zirSetCold(block, inst);
                i += 1;
                continue;
            },
            .set_float_mode => {
                try sema.zirSetFloatMode(block, inst);
                i += 1;
                continue;
            },
            .set_runtime_safety => {
                try sema.zirSetRuntimeSafety(block, inst);
                i += 1;
                continue;
            },
            .param => {
                try sema.zirParam(block, inst, false);
                i += 1;
                continue;
            },
            .param_comptime => {
                try sema.zirParam(block, inst, true);
                i += 1;
                continue;
            },
            .param_anytype => {
                try sema.zirParamAnytype(block, inst, false);
                i += 1;
                continue;
            },
            .param_anytype_comptime => {
                try sema.zirParamAnytype(block, inst, true);
                i += 1;
                continue;
            },
            .closure_capture => {
                try sema.zirClosureCapture(block, inst);
                i += 1;
                continue;
            },
            .memcpy => {
                try sema.zirMemcpy(block, inst);
                i += 1;
                continue;
            },
            .memset => {
                try sema.zirMemset(block, inst);
                i += 1;
                continue;
            },

            // Special case instructions to handle comptime control flow.
            .@"break" => {
                if (block.is_comptime) {
                    break inst; // same as break_inline
                } else {
                    break sema.zirBreak(block, inst);
                }
            },
            .break_inline => break inst,
            .repeat => {
                if (block.is_comptime) {
                    // Send comptime control flow back to the beginning of this block.
                    const src: LazySrcLoc = .{ .node_offset = datas[inst].node };
                    try sema.emitBackwardBranch(block, src);
                    if (wip_captures.scope.captures.count() != orig_captures) {
                        try wip_captures.reset(parent_capture_scope);
                        block.wip_capture_scope = wip_captures.scope;
                        orig_captures = 0;
                    }
                    i = 0;
                    continue;
                } else {
                    const src_node = sema.code.instructions.items(.data)[inst].node;
                    const src: LazySrcLoc = .{ .node_offset = src_node };
                    try sema.requireRuntimeBlock(block, src);
                    break always_noreturn;
                }
            },
            .repeat_inline => {
                // Send comptime control flow back to the beginning of this block.
                const src: LazySrcLoc = .{ .node_offset = datas[inst].node };
                try sema.emitBackwardBranch(block, src);
                if (wip_captures.scope.captures.count() != orig_captures) {
                    try wip_captures.reset(parent_capture_scope);
                    block.wip_capture_scope = wip_captures.scope;
                    orig_captures = 0;
                }
                i = 0;
                continue;
            },
            .loop => blk: {
                if (!block.is_comptime) break :blk try sema.zirLoop(block, inst);
                // Same as `block_inline`. TODO https://github.com/ziglang/zig/issues/8220
                const inst_data = datas[inst].pl_node;
                const extra = sema.code.extraData(Zir.Inst.Block, inst_data.payload_index);
                const inline_body = sema.code.extra[extra.end..][0..extra.data.body_len];
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk sema.resolveInst(break_data.operand);
                } else {
                    break break_inst;
                }
            },
            .block => blk: {
                if (!block.is_comptime) break :blk try sema.zirBlock(block, inst);
                // Same as `block_inline`. TODO https://github.com/ziglang/zig/issues/8220
                const inst_data = datas[inst].pl_node;
                const extra = sema.code.extraData(Zir.Inst.Block, inst_data.payload_index);
                const inline_body = sema.code.extra[extra.end..][0..extra.data.body_len];
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk sema.resolveInst(break_data.operand);
                } else {
                    break break_inst;
                }
            },
            .block_inline => blk: {
                // Directly analyze the block body without introducing a new block.
                const inst_data = datas[inst].pl_node;
                const extra = sema.code.extraData(Zir.Inst.Block, inst_data.payload_index);
                const inline_body = sema.code.extra[extra.end..][0..extra.data.body_len];
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk sema.resolveInst(break_data.operand);
                } else {
                    break break_inst;
                }
            },
            .condbr => blk: {
                if (!block.is_comptime) break sema.zirCondbr(block, inst);
                // Same as condbr_inline. TODO https://github.com/ziglang/zig/issues/8220
                const inst_data = datas[inst].pl_node;
                const cond_src: LazySrcLoc = .{ .node_offset_if_cond = inst_data.src_node };
                const extra = sema.code.extraData(Zir.Inst.CondBr, inst_data.payload_index);
                const then_body = sema.code.extra[extra.end..][0..extra.data.then_body_len];
                const else_body = sema.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
                const cond = try sema.resolveInstConst(block, cond_src, extra.data.condition);
                const inline_body = if (cond.val.toBool()) then_body else else_body;
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk sema.resolveInst(break_data.operand);
                } else {
                    break break_inst;
                }
            },
            .condbr_inline => blk: {
                const inst_data = datas[inst].pl_node;
                const cond_src: LazySrcLoc = .{ .node_offset_if_cond = inst_data.src_node };
                const extra = sema.code.extraData(Zir.Inst.CondBr, inst_data.payload_index);
                const then_body = sema.code.extra[extra.end..][0..extra.data.then_body_len];
                const else_body = sema.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
                const cond = try sema.resolveInstConst(block, cond_src, extra.data.condition);
                const inline_body = if (cond.val.toBool()) then_body else else_body;
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk sema.resolveInst(break_data.operand);
                } else {
                    break break_inst;
                }
            },
        };
        if (sema.typeOf(air_inst).isNoReturn())
            break always_noreturn;
        try map.put(sema.gpa, inst, air_inst);
        i += 1;
    } else unreachable;

    if (!wip_captures.finalized) {
        try wip_captures.finalize();
        block.wip_capture_scope = parent_capture_scope;
    }

    return result;
}

fn zirExtended(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const extended = sema.code.instructions.items(.data)[inst].extended;
    switch (extended.opcode) {
        // zig fmt: off
        .func               => return sema.zirFuncExtended(      block, extended, inst),
        .variable           => return sema.zirVarExtended(       block, extended),
        .struct_decl        => return sema.zirStructDecl(        block, extended, inst),
        .enum_decl          => return sema.zirEnumDecl(          block, extended),
        .union_decl         => return sema.zirUnionDecl(         block, extended, inst),
        .opaque_decl        => return sema.zirOpaqueDecl(        block, extended),
        .ret_ptr            => return sema.zirRetPtr(            block, extended),
        .ret_type           => return sema.zirRetType(           block, extended),
        .this               => return sema.zirThis(              block, extended),
        .ret_addr           => return sema.zirRetAddr(           block, extended),
        .builtin_src        => return sema.zirBuiltinSrc(        block, extended),
        .error_return_trace => return sema.zirErrorReturnTrace(  block, extended),
        .frame              => return sema.zirFrame(             block, extended),
        .frame_address      => return sema.zirFrameAddress(      block, extended),
        .alloc              => return sema.zirAllocExtended(     block, extended),
        .builtin_extern     => return sema.zirBuiltinExtern(     block, extended),
        .@"asm"             => return sema.zirAsm(               block, extended, inst),
        .typeof_peer        => return sema.zirTypeofPeer(        block, extended),
        .compile_log        => return sema.zirCompileLog(        block, extended),
        .add_with_overflow  => return sema.zirOverflowArithmetic(block, extended),
        .sub_with_overflow  => return sema.zirOverflowArithmetic(block, extended),
        .mul_with_overflow  => return sema.zirOverflowArithmetic(block, extended),
        .shl_with_overflow  => return sema.zirOverflowArithmetic(block, extended),
        .c_undef            => return sema.zirCUndef(            block, extended),
        .c_include          => return sema.zirCInclude(          block, extended),
        .c_define           => return sema.zirCDefine(           block, extended),
        .wasm_memory_size   => return sema.zirWasmMemorySize(    block, extended),
        .wasm_memory_grow   => return sema.zirWasmMemoryGrow(    block, extended),
        // zig fmt: on
    }
}

pub fn resolveInst(sema: *Sema, zir_ref: Zir.Inst.Ref) Air.Inst.Ref {
    var i: usize = @enumToInt(zir_ref);

    // First section of indexes correspond to a set number of constant values.
    if (i < Zir.Inst.Ref.typed_value_map.len) {
        // We intentionally map the same indexes to the same values between ZIR and AIR.
        return zir_ref;
    }
    i -= Zir.Inst.Ref.typed_value_map.len;

    // Finally, the last section of indexes refers to the map of ZIR=>AIR.
    return sema.inst_map.get(@intCast(u32, i)).?;
}

fn resolveConstBool(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) !bool {
    const air_inst = sema.resolveInst(zir_ref);
    const wanted_type = Type.initTag(.bool);
    const coerced_inst = try sema.coerce(block, wanted_type, air_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced_inst);
    return val.toBool();
}

fn resolveConstString(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) ![]u8 {
    const air_inst = sema.resolveInst(zir_ref);
    const wanted_type = Type.initTag(.const_slice_u8);
    const coerced_inst = try sema.coerce(block, wanted_type, air_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced_inst);
    return val.toAllocatedBytes(wanted_type, sema.arena);
}

pub fn resolveType(sema: *Sema, block: *Block, src: LazySrcLoc, zir_ref: Zir.Inst.Ref) !Type {
    const air_inst = sema.resolveInst(zir_ref);
    const ty = try sema.analyzeAsType(block, src, air_inst);
    if (ty.tag() == .generic_poison) return error.GenericPoison;
    return ty;
}

fn analyzeAsType(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    air_inst: Air.Inst.Ref,
) !Type {
    const wanted_type = Type.initTag(.@"type");
    const coerced_inst = try sema.coerce(block, wanted_type, air_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced_inst);
    var buffer: Value.ToTypeBuffer = undefined;
    const ty = val.toType(&buffer);
    return ty.copy(sema.arena);
}

/// May return Value Tags: `variable`, `undef`.
/// See `resolveConstValue` for an alternative.
/// Value Tag `generic_poison` causes `error.GenericPoison` to be returned.
fn resolveValue(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    air_ref: Air.Inst.Ref,
) CompileError!Value {
    if (try sema.resolveMaybeUndefValAllowVariables(block, src, air_ref)) |val| {
        if (val.tag() == .generic_poison) return error.GenericPoison;
        return val;
    }
    return sema.failWithNeededComptime(block, src);
}

/// Value Tag `variable` will cause a compile error.
/// Value Tag `undef` may be returned.
fn resolveConstMaybeUndefVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    inst: Air.Inst.Ref,
) CompileError!Value {
    if (try sema.resolveMaybeUndefValAllowVariables(block, src, inst)) |val| {
        switch (val.tag()) {
            .variable => return sema.failWithNeededComptime(block, src),
            .generic_poison => return error.GenericPoison,
            else => return val,
        }
    }
    return sema.failWithNeededComptime(block, src);
}

/// Will not return Value Tags: `variable`, `undef`. Instead they will emit compile errors.
/// See `resolveValue` for an alternative.
fn resolveConstValue(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    air_ref: Air.Inst.Ref,
) CompileError!Value {
    if (try sema.resolveMaybeUndefValAllowVariables(block, src, air_ref)) |val| {
        switch (val.tag()) {
            .undef => return sema.failWithUseOfUndef(block, src),
            .variable => return sema.failWithNeededComptime(block, src),
            .generic_poison => return error.GenericPoison,
            else => return val,
        }
    }
    return sema.failWithNeededComptime(block, src);
}

/// Value Tag `variable` causes this function to return `null`.
/// Value Tag `undef` causes this function to return a compile error.
fn resolveDefinedValue(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    air_ref: Air.Inst.Ref,
) CompileError!?Value {
    if (try sema.resolveMaybeUndefVal(block, src, air_ref)) |val| {
        if (val.isUndef()) {
            return sema.failWithUseOfUndef(block, src);
        }
        return val;
    }
    return null;
}

/// Value Tag `variable` causes this function to return `null`.
/// Value Tag `undef` causes this function to return the Value.
/// Value Tag `generic_poison` causes `error.GenericPoison` to be returned.
fn resolveMaybeUndefVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    inst: Air.Inst.Ref,
) CompileError!?Value {
    const val = (try sema.resolveMaybeUndefValAllowVariables(block, src, inst)) orelse return null;
    switch (val.tag()) {
        .variable => return null,
        .generic_poison => return error.GenericPoison,
        else => return val,
    }
}

/// Returns all Value tags including `variable` and `undef`.
fn resolveMaybeUndefValAllowVariables(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    inst: Air.Inst.Ref,
) CompileError!?Value {
    // First section of indexes correspond to a set number of constant values.
    var i: usize = @enumToInt(inst);
    if (i < Air.Inst.Ref.typed_value_map.len) {
        return Air.Inst.Ref.typed_value_map[i].val;
    }
    i -= Air.Inst.Ref.typed_value_map.len;

    if (try sema.typeHasOnePossibleValue(block, src, sema.typeOf(inst))) |opv| {
        return opv;
    }
    const air_tags = sema.air_instructions.items(.tag);
    switch (air_tags[i]) {
        .constant => {
            const ty_pl = sema.air_instructions.items(.data)[i].ty_pl;
            return sema.air_values.items[ty_pl.payload];
        },
        .const_ty => {
            return try sema.air_instructions.items(.data)[i].ty.toValue(sema.arena);
        },
        else => return null,
    }
}

fn failWithNeededComptime(sema: *Sema, block: *Block, src: LazySrcLoc) CompileError {
    return sema.fail(block, src, "unable to resolve comptime value", .{});
}

fn failWithUseOfUndef(sema: *Sema, block: *Block, src: LazySrcLoc) CompileError {
    return sema.fail(block, src, "use of undefined value here causes undefined behavior", .{});
}

fn failWithDivideByZero(sema: *Sema, block: *Block, src: LazySrcLoc) CompileError {
    return sema.fail(block, src, "division by zero here causes undefined behavior", .{});
}

fn failWithModRemNegative(sema: *Sema, block: *Block, src: LazySrcLoc, lhs_ty: Type, rhs_ty: Type) CompileError {
    return sema.fail(block, src, "remainder division with '{}' and '{}': signed integers and floats must use @rem or @mod", .{ lhs_ty, rhs_ty });
}

fn failWithExpectedOptionalType(sema: *Sema, block: *Block, src: LazySrcLoc, optional_ty: Type) CompileError {
    return sema.fail(block, src, "expected optional type, found {}", .{optional_ty});
}

fn failWithErrorSetCodeMissing(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    dest_err_set_ty: Type,
    src_err_set_ty: Type,
) CompileError {
    return sema.fail(block, src, "expected type '{}', found type '{}'", .{
        dest_err_set_ty, src_err_set_ty,
    });
}

/// We don't return a pointer to the new error note because the pointer
/// becomes invalid when you add another one.
fn errNote(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    parent: *Module.ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    return sema.mod.errNoteNonLazy(src.toSrcLoc(block.src_decl), parent, format, args);
}

fn errMsg(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!*Module.ErrorMsg {
    return Module.ErrorMsg.create(sema.gpa, src.toSrcLoc(block.src_decl), format, args);
}

pub fn fail(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) CompileError {
    const err_msg = try sema.errMsg(block, src, format, args);
    return sema.failWithOwnedErrorMsg(err_msg);
}

fn failWithOwnedErrorMsg(sema: *Sema, err_msg: *Module.ErrorMsg) CompileError {
    @setCold(true);

    if (crash_report.is_enabled and sema.mod.comp.debug_compile_errors) {
        std.debug.print("compile error during Sema: {s}, src: {s}:{}\n", .{
            err_msg.msg,
            err_msg.src_loc.file_scope.sub_file_path,
            err_msg.src_loc.lazy,
        });
        crash_report.compilerPanic("unexpected compile error occurred", null);
    }

    const mod = sema.mod;

    {
        errdefer err_msg.destroy(mod.gpa);
        if (err_msg.src_loc.lazy == .unneeded) {
            return error.NeededSourceLocation;
        }
        try mod.failed_decls.ensureUnusedCapacity(mod.gpa, 1);
        try mod.failed_files.ensureUnusedCapacity(mod.gpa, 1);
    }
    if (sema.owner_func) |func| {
        func.state = .sema_failure;
    } else {
        sema.owner_decl.analysis = .sema_failure;
        sema.owner_decl.generation = mod.generation;
    }
    mod.failed_decls.putAssumeCapacityNoClobber(sema.owner_decl, err_msg);
    return error.AnalysisFail;
}

/// Appropriate to call when the coercion has already been done by result
/// location semantics. Asserts the value fits in the provided `Int` type.
/// Only supports `Int` types 64 bits or less.
/// TODO don't ever call this since we're migrating towards ResultLoc.coerced_ty.
fn resolveAlreadyCoercedInt(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
    comptime Int: type,
) !Int {
    comptime assert(@typeInfo(Int).Int.bits <= 64);
    const air_inst = sema.resolveInst(zir_ref);
    const val = try sema.resolveConstValue(block, src, air_inst);
    switch (@typeInfo(Int).Int.signedness) {
        .signed => return @intCast(Int, val.toSignedInt()),
        .unsigned => return @intCast(Int, val.toUnsignedInt()),
    }
}

fn resolveAlign(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) !u16 {
    const alignment_big = try sema.resolveInt(block, src, zir_ref, Type.initTag(.u16));
    const alignment = @intCast(u16, alignment_big); // We coerce to u16 in the prev line.
    if (alignment == 0) return sema.fail(block, src, "alignment must be >= 1", .{});
    if (!std.math.isPowerOfTwo(alignment)) {
        return sema.fail(block, src, "alignment value {d} is not a power of two", .{
            alignment,
        });
    }
    return alignment;
}

fn resolveInt(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
    dest_ty: Type,
) !u64 {
    const air_inst = sema.resolveInst(zir_ref);
    const coerced = try sema.coerce(block, dest_ty, air_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced);

    return val.toUnsignedInt();
}

// Returns a compile error if the value has tag `variable`. See `resolveInstValue` for
// a function that does not.
pub fn resolveInstConst(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) CompileError!TypedValue {
    const air_ref = sema.resolveInst(zir_ref);
    const val = try sema.resolveConstValue(block, src, air_ref);
    return TypedValue{
        .ty = sema.typeOf(air_ref),
        .val = val,
    };
}

// Value Tag may be `undef` or `variable`.
// See `resolveInstConst` for an alternative.
pub fn resolveInstValue(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) CompileError!TypedValue {
    const air_ref = sema.resolveInst(zir_ref);
    const val = try sema.resolveValue(block, src, air_ref);
    return TypedValue{
        .ty = sema.typeOf(air_ref),
        .val = val,
    };
}

fn zirCoerceResultPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = sema.src;
    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const pointee_ty = try sema.resolveType(block, src, bin_inst.lhs);
    const ptr = sema.resolveInst(bin_inst.rhs);

    const ptr_ty = try Type.ptr(sema.arena, .{
        .pointee_type = pointee_ty,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });

    if (Air.refToIndex(ptr)) |ptr_inst| {
        if (sema.air_instructions.items(.tag)[ptr_inst] == .constant) {
            const air_datas = sema.air_instructions.items(.data);
            const ptr_val = sema.air_values.items[air_datas[ptr_inst].ty_pl.payload];
            switch (ptr_val.tag()) {
                .inferred_alloc => {
                    const inferred_alloc = &ptr_val.castTag(.inferred_alloc).?.data;
                    // Add the stored instruction to the set we will use to resolve peer types
                    // for the inferred allocation.
                    // This instruction will not make it to codegen; it is only to participate
                    // in the `stored_inst_list` of the `inferred_alloc`.
                    const operand = try block.addBitCast(pointee_ty, .void_value);
                    try inferred_alloc.stored_inst_list.append(sema.arena, operand);
                },
                .inferred_alloc_comptime => {
                    const iac = ptr_val.castTag(.inferred_alloc_comptime).?;
                    // There will be only one coerce_result_ptr because we are running at comptime.
                    // The alloc will turn into a Decl.
                    var anon_decl = try block.startAnonDecl();
                    defer anon_decl.deinit();
                    iac.data = try anon_decl.finish(
                        try pointee_ty.copy(anon_decl.arena()),
                        Value.undef,
                    );
                    return sema.addConstant(
                        ptr_ty,
                        try Value.Tag.decl_ref_mut.create(sema.arena, .{
                            .decl = iac.data,
                            .runtime_index = block.runtime_index,
                        }),
                    );
                },
                .decl_ref_mut => return sema.addConstant(ptr_ty, ptr_val),
                else => {},
            }
        }
    }
    try sema.requireRuntimeBlock(block, src);
    const bitcasted_ptr = try block.addBitCast(ptr_ty, ptr);
    return bitcasted_ptr;
}

pub fn analyzeStructDecl(
    sema: *Sema,
    new_decl: *Decl,
    inst: Zir.Inst.Index,
    struct_obj: *Module.Struct,
) SemaError!void {
    const extended = sema.code.instructions.items(.data)[inst].extended;
    assert(extended.opcode == .struct_decl);
    const small = @bitCast(Zir.Inst.StructDecl.Small, extended.small);

    struct_obj.known_has_bits = small.known_has_bits;

    var extra_index: usize = extended.operand;
    extra_index += @boolToInt(small.has_src_node);
    extra_index += @boolToInt(small.has_body_len);
    extra_index += @boolToInt(small.has_fields_len);
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;

    _ = try sema.mod.scanNamespace(&struct_obj.namespace, extra_index, decls_len, new_decl);
}

fn zirStructDecl(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const small = @bitCast(Zir.Inst.StructDecl.Small, extended.small);
    const src: LazySrcLoc = if (small.has_src_node) blk: {
        const node_offset = @bitCast(i32, sema.code.extra[extended.operand]);
        break :blk .{ .node_offset = node_offset };
    } else sema.src;

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const struct_obj = try new_decl_arena.allocator.create(Module.Struct);
    const struct_ty = try Type.Tag.@"struct".create(&new_decl_arena.allocator, struct_obj);
    const struct_val = try Value.Tag.ty.create(&new_decl_arena.allocator, struct_ty);
    const type_name = try sema.createTypeName(block, small.name_strategy);
    const new_decl = try sema.mod.createAnonymousDeclNamed(block, .{
        .ty = Type.type,
        .val = struct_val,
    }, type_name);
    new_decl.owns_tv = true;
    errdefer sema.mod.abortAnonDecl(new_decl);
    struct_obj.* = .{
        .owner_decl = new_decl,
        .fields = .{},
        .node_offset = src.node_offset,
        .zir_index = inst,
        .layout = small.layout,
        .status = .none,
        .known_has_bits = undefined,
        .namespace = .{
            .parent = block.namespace,
            .ty = struct_ty,
            .file_scope = block.getFileScope(),
        },
    };
    std.log.scoped(.module).debug("create struct {*} owned by {*} ({s})", .{
        &struct_obj.namespace, new_decl, new_decl.name,
    });
    try sema.analyzeStructDecl(new_decl, inst, struct_obj);
    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn createTypeName(sema: *Sema, block: *Block, name_strategy: Zir.Inst.NameStrategy) ![:0]u8 {
    switch (name_strategy) {
        .anon => {
            // It would be neat to have "struct:line:column" but this name has
            // to survive incremental updates, where it may have been shifted down
            // or up to a different line, but unchanged, and thus not unnecessarily
            // semantically analyzed.
            const name_index = sema.mod.getNextAnonNameIndex();
            return std.fmt.allocPrintZ(sema.gpa, "{s}__anon_{d}", .{
                block.src_decl.name, name_index,
            });
        },
        .parent => return sema.gpa.dupeZ(u8, mem.spanZ(block.src_decl.name)),
        .func => {
            const name_index = sema.mod.getNextAnonNameIndex();
            const name = try std.fmt.allocPrintZ(sema.gpa, "{s}__anon_{d}", .{
                block.src_decl.name, name_index,
            });
            log.warn("TODO: handle NameStrategy.func correctly instead of using anon name '{s}'", .{
                name,
            });
            return name;
        },
    }
}

fn zirEnumDecl(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = sema.mod;
    const gpa = sema.gpa;
    const small = @bitCast(Zir.Inst.EnumDecl.Small, extended.small);
    var extra_index: usize = extended.operand;

    const src: LazySrcLoc = if (small.has_src_node) blk: {
        const node_offset = @bitCast(i32, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk .{ .node_offset = node_offset };
    } else sema.src;

    const tag_type_ref = if (small.has_tag_type) blk: {
        const tag_type_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk tag_type_ref;
    } else .none;

    const body_len = if (small.has_body_len) blk: {
        const body_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk body_len;
    } else 0;

    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;

    var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
    errdefer new_decl_arena.deinit();

    const enum_obj = try new_decl_arena.allocator.create(Module.EnumFull);
    const enum_ty_payload = try new_decl_arena.allocator.create(Type.Payload.EnumFull);
    enum_ty_payload.* = .{
        .base = .{ .tag = if (small.nonexhaustive) .enum_nonexhaustive else .enum_full },
        .data = enum_obj,
    };
    const enum_ty = Type.initPayload(&enum_ty_payload.base);
    const enum_val = try Value.Tag.ty.create(&new_decl_arena.allocator, enum_ty);
    const type_name = try sema.createTypeName(block, small.name_strategy);
    const new_decl = try mod.createAnonymousDeclNamed(block, .{
        .ty = Type.type,
        .val = enum_val,
    }, type_name);
    new_decl.owns_tv = true;
    errdefer mod.abortAnonDecl(new_decl);

    enum_obj.* = .{
        .owner_decl = new_decl,
        .tag_ty = Type.initTag(.@"null"),
        .fields = .{},
        .values = .{},
        .node_offset = src.node_offset,
        .namespace = .{
            .parent = block.namespace,
            .ty = enum_ty,
            .file_scope = block.getFileScope(),
        },
    };
    std.log.scoped(.module).debug("create enum {*} owned by {*} ({s})", .{
        &enum_obj.namespace, new_decl, new_decl.name,
    });

    extra_index = try mod.scanNamespace(&enum_obj.namespace, extra_index, decls_len, new_decl);

    const body = sema.code.extra[extra_index..][0..body_len];
    if (fields_len == 0) {
        assert(body.len == 0);
        try new_decl.finalizeNewArena(&new_decl_arena);
        return sema.analyzeDeclVal(block, src, new_decl);
    }
    extra_index += body.len;

    const bit_bags_count = std.math.divCeil(usize, fields_len, 32) catch unreachable;
    const body_end = extra_index;
    extra_index += bit_bags_count;

    {
        // We create a block for the field type instructions because they
        // may need to reference Decls from inside the enum namespace.
        // Within the field type, default value, and alignment expressions, the "owner decl"
        // should be the enum itself.

        const prev_owner_decl = sema.owner_decl;
        sema.owner_decl = new_decl;
        defer sema.owner_decl = prev_owner_decl;

        const prev_owner_func = sema.owner_func;
        sema.owner_func = null;
        defer sema.owner_func = prev_owner_func;

        const prev_func = sema.func;
        sema.func = null;
        defer sema.func = prev_func;

        var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, new_decl.src_scope);
        defer wip_captures.deinit();

        var enum_block: Block = .{
            .parent = null,
            .sema = sema,
            .src_decl = new_decl,
            .namespace = &enum_obj.namespace,
            .wip_capture_scope = wip_captures.scope,
            .instructions = .{},
            .inlining = null,
            .is_comptime = true,
        };
        defer assert(enum_block.instructions.items.len == 0); // should all be comptime instructions

        if (body.len != 0) {
            _ = try sema.analyzeBody(&enum_block, body);
        }

        try wip_captures.finalize();

        const tag_ty = blk: {
            if (tag_type_ref != .none) {
                // TODO better source location
                break :blk try sema.resolveType(block, src, tag_type_ref);
            }
            const bits = std.math.log2_int_ceil(usize, fields_len);
            break :blk try Type.Tag.int_unsigned.create(&new_decl_arena.allocator, bits);
        };
        enum_obj.tag_ty = tag_ty;
    }

    try enum_obj.fields.ensureTotalCapacity(&new_decl_arena.allocator, fields_len);
    const any_values = for (sema.code.extra[body_end..][0..bit_bags_count]) |bag| {
        if (bag != 0) break true;
    } else false;
    if (any_values) {
        try enum_obj.values.ensureTotalCapacityContext(&new_decl_arena.allocator, fields_len, .{
            .ty = enum_obj.tag_ty,
        });
    }

    var bit_bag_index: usize = body_end;
    var cur_bit_bag: u32 = undefined;
    var field_i: u32 = 0;
    while (field_i < fields_len) : (field_i += 1) {
        if (field_i % 32 == 0) {
            cur_bit_bag = sema.code.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const has_tag_value = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        const field_name_zir = sema.code.nullTerminatedString(sema.code.extra[extra_index]);
        extra_index += 1;

        // This string needs to outlive the ZIR code.
        const field_name = try new_decl_arena.allocator.dupe(u8, field_name_zir);

        const gop = enum_obj.fields.getOrPutAssumeCapacity(field_name);
        if (gop.found_existing) {
            const tree = try sema.getAstTree(block);
            const field_src = enumFieldSrcLoc(block.src_decl, tree.*, src.node_offset, field_i);
            const other_tag_src = enumFieldSrcLoc(block.src_decl, tree.*, src.node_offset, gop.index);
            const msg = msg: {
                const msg = try sema.errMsg(block, field_src, "duplicate enum tag", .{});
                errdefer msg.destroy(gpa);
                try sema.errNote(block, other_tag_src, msg, "other tag here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }

        if (has_tag_value) {
            const tag_val_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
            extra_index += 1;
            // TODO: if we need to report an error here, use a source location
            // that points to this default value expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            const tag_val = (try sema.resolveInstConst(block, src, tag_val_ref)).val;
            const copied_tag_val = try tag_val.copy(&new_decl_arena.allocator);
            enum_obj.values.putAssumeCapacityNoClobberContext(copied_tag_val, {}, .{
                .ty = enum_obj.tag_ty,
            });
        } else if (any_values) {
            const tag_val = try Value.Tag.int_u64.create(&new_decl_arena.allocator, field_i);
            enum_obj.values.putAssumeCapacityNoClobberContext(tag_val, {}, .{ .ty = enum_obj.tag_ty });
        }
    }

    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn zirUnionDecl(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const small = @bitCast(Zir.Inst.UnionDecl.Small, extended.small);
    var extra_index: usize = extended.operand;

    const src: LazySrcLoc = if (small.has_src_node) blk: {
        const node_offset = @bitCast(i32, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk .{ .node_offset = node_offset };
    } else sema.src;

    extra_index += @boolToInt(small.has_tag_type);
    extra_index += @boolToInt(small.has_body_len);
    extra_index += @boolToInt(small.has_fields_len);

    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const union_obj = try new_decl_arena.allocator.create(Module.Union);
    const type_tag: Type.Tag = if (small.has_tag_type or small.auto_enum_tag) .union_tagged else .@"union";
    const union_payload = try new_decl_arena.allocator.create(Type.Payload.Union);
    union_payload.* = .{
        .base = .{ .tag = type_tag },
        .data = union_obj,
    };
    const union_ty = Type.initPayload(&union_payload.base);
    const union_val = try Value.Tag.ty.create(&new_decl_arena.allocator, union_ty);
    const type_name = try sema.createTypeName(block, small.name_strategy);
    const new_decl = try sema.mod.createAnonymousDeclNamed(block, .{
        .ty = Type.type,
        .val = union_val,
    }, type_name);
    new_decl.owns_tv = true;
    errdefer sema.mod.abortAnonDecl(new_decl);
    union_obj.* = .{
        .owner_decl = new_decl,
        .tag_ty = Type.initTag(.@"null"),
        .fields = .{},
        .node_offset = src.node_offset,
        .zir_index = inst,
        .layout = small.layout,
        .status = .none,
        .namespace = .{
            .parent = block.namespace,
            .ty = union_ty,
            .file_scope = block.getFileScope(),
        },
    };
    std.log.scoped(.module).debug("create union {*} owned by {*} ({s})", .{
        &union_obj.namespace, new_decl, new_decl.name,
    });

    _ = try sema.mod.scanNamespace(&union_obj.namespace, extra_index, decls_len, new_decl);

    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn zirOpaqueDecl(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = sema.mod;
    const gpa = sema.gpa;
    const small = @bitCast(Zir.Inst.OpaqueDecl.Small, extended.small);
    var extra_index: usize = extended.operand;

    const src: LazySrcLoc = if (small.has_src_node) blk: {
        const node_offset = @bitCast(i32, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk .{ .node_offset = node_offset };
    } else sema.src;

    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = sema.code.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;

    var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
    errdefer new_decl_arena.deinit();

    const opaque_obj = try new_decl_arena.allocator.create(Module.Opaque);
    const opaque_ty_payload = try new_decl_arena.allocator.create(Type.Payload.Opaque);
    opaque_ty_payload.* = .{
        .base = .{ .tag = .@"opaque" },
        .data = opaque_obj,
    };
    const opaque_ty = Type.initPayload(&opaque_ty_payload.base);
    const opaque_val = try Value.Tag.ty.create(&new_decl_arena.allocator, opaque_ty);
    const type_name = try sema.createTypeName(block, small.name_strategy);
    const new_decl = try mod.createAnonymousDeclNamed(block, .{
        .ty = Type.type,
        .val = opaque_val,
    }, type_name);
    new_decl.owns_tv = true;
    errdefer mod.abortAnonDecl(new_decl);

    opaque_obj.* = .{
        .owner_decl = new_decl,
        .node_offset = src.node_offset,
        .namespace = .{
            .parent = block.namespace,
            .ty = opaque_ty,
            .file_scope = block.getFileScope(),
        },
    };
    std.log.scoped(.module).debug("create opaque {*} owned by {*} ({s})", .{
        &opaque_obj.namespace, new_decl, new_decl.name,
    });

    extra_index = try mod.scanNamespace(&opaque_obj.namespace, extra_index, decls_len, new_decl);

    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn zirErrorSetDecl(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    name_strategy: Zir.Inst.NameStrategy,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = sema.gpa;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.ErrorSetDecl, inst_data.payload_index);
    const fields = sema.code.extra[extra.end..][0..extra.data.fields_len];

    var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
    errdefer new_decl_arena.deinit();

    const error_set = try new_decl_arena.allocator.create(Module.ErrorSet);
    const error_set_ty = try Type.Tag.error_set.create(&new_decl_arena.allocator, error_set);
    const error_set_val = try Value.Tag.ty.create(&new_decl_arena.allocator, error_set_ty);
    const type_name = try sema.createTypeName(block, name_strategy);
    const new_decl = try sema.mod.createAnonymousDeclNamed(block, .{
        .ty = Type.type,
        .val = error_set_val,
    }, type_name);
    new_decl.owns_tv = true;
    errdefer sema.mod.abortAnonDecl(new_decl);
    const names = try new_decl_arena.allocator.alloc([]const u8, fields.len);
    for (fields) |str_index, i| {
        names[i] = try new_decl_arena.allocator.dupe(u8, sema.code.nullTerminatedString(str_index));
    }
    error_set.* = .{
        .owner_decl = new_decl,
        .node_offset = inst_data.src_node,
        .names_ptr = names.ptr,
        .names_len = @intCast(u32, names.len),
    };
    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn zirRetPtr(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    try sema.requireFunctionBlock(block, src);

    if (block.is_comptime) {
        return sema.analyzeComptimeAlloc(block, sema.fn_ret_ty, 0);
    }

    const ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = sema.fn_ret_ty,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });

    if (block.inlining != null) {
        // We are inlining a function call; this should be emitted as an alloc, not a ret_ptr.
        // TODO when functions gain result location support, the inlining struct in
        // Block should contain the return pointer, and we would pass that through here.
        return block.addTy(.alloc, ptr_type);
    }

    return block.addTy(.ret_ptr, ptr_type);
}

fn zirRef(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const operand = sema.resolveInst(inst_data.operand);
    return sema.analyzeRef(block, inst_data.src(), operand);
}

fn zirRetType(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    try sema.requireFunctionBlock(block, src);
    return sema.addType(sema.fn_ret_ty);
}

fn zirEnsureResultUsed(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.ensureResultUsed(block, operand, src);
}

fn ensureResultUsed(
    sema: *Sema,
    block: *Block,
    operand: Air.Inst.Ref,
    src: LazySrcLoc,
) CompileError!void {
    const operand_ty = sema.typeOf(operand);
    switch (operand_ty.zigTypeTag()) {
        .Void, .NoReturn => return,
        else => return sema.fail(block, src, "expression value is ignored", .{}),
    }
}

fn zirEnsureResultNonError(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = sema.resolveInst(inst_data.operand);
    const src = inst_data.src();
    const operand_ty = sema.typeOf(operand);
    switch (operand_ty.zigTypeTag()) {
        .ErrorSet, .ErrorUnion => return sema.fail(block, src, "error is discarded", .{}),
        else => return,
    }
}

fn zirIndexablePtrLen(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const object = sema.resolveInst(inst_data.operand);
    const object_ty = sema.typeOf(object);

    const is_pointer_to = object_ty.isSinglePointer();

    const array_ty = if (is_pointer_to)
        object_ty.childType()
    else
        object_ty;

    if (!array_ty.isIndexable()) {
        const msg = msg: {
            const msg = try sema.errMsg(
                block,
                src,
                "type '{}' does not support indexing",
                .{array_ty},
            );
            errdefer msg.destroy(sema.gpa);
            try sema.errNote(
                block,
                src,
                msg,
                "for loop operand must be an array, slice, tuple, or vector",
                .{},
            );
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }

    return sema.fieldVal(block, src, object, "len", src);
}

fn zirAllocExtended(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.AllocExtended, extended.operand);
    const src: LazySrcLoc = .{ .node_offset = extra.data.src_node };
    const ty_src = src; // TODO better source location
    const align_src = src; // TODO better source location
    const small = @bitCast(Zir.Inst.AllocExtended.Small, extended.small);

    var extra_index: usize = extra.end;

    const var_ty: Type = if (small.has_type) blk: {
        const type_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk try sema.resolveType(block, ty_src, type_ref);
    } else undefined;

    const alignment: u16 = if (small.has_align) blk: {
        const align_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        const alignment = try sema.resolveAlign(block, align_src, align_ref);
        break :blk alignment;
    } else 0;

    const inferred_alloc_ty = if (small.is_const)
        Type.initTag(.inferred_alloc_const)
    else
        Type.initTag(.inferred_alloc_mut);

    if (small.is_comptime) {
        if (small.has_type) {
            return sema.analyzeComptimeAlloc(block, var_ty, alignment);
        } else {
            return sema.addConstant(
                inferred_alloc_ty,
                try Value.Tag.inferred_alloc_comptime.create(sema.arena, undefined),
            );
        }
    }

    if (small.has_type) {
        if (!small.is_const) {
            try sema.validateVarType(block, ty_src, var_ty, false);
        }
        const ptr_type = try Type.ptr(sema.arena, .{
            .pointee_type = var_ty,
            .@"align" = alignment,
            .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
        });
        try sema.requireRuntimeBlock(block, src);
        try sema.resolveTypeLayout(block, src, var_ty);
        return block.addTy(.alloc, ptr_type);
    }

    // `Sema.addConstant` does not add the instruction to the block because it is
    // not needed in the case of constant values. However here, we plan to "downgrade"
    // to a normal instruction when we hit `resolve_inferred_alloc`. So we append
    // to the block even though it is currently a `.constant`.
    const result = try sema.addConstant(
        inferred_alloc_ty,
        try Value.Tag.inferred_alloc.create(sema.arena, .{}),
    );
    try sema.requireFunctionBlock(block, src);
    try block.instructions.append(sema.gpa, Air.refToIndex(result).?);
    return result;
}

fn zirAllocComptime(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const var_ty = try sema.resolveType(block, ty_src, inst_data.operand);
    return sema.analyzeComptimeAlloc(block, var_ty, 0);
}

fn zirAllocInferredComptime(sema: *Sema, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };
    sema.src = src;
    return sema.addConstant(
        Type.initTag(.inferred_alloc_mut),
        try Value.Tag.inferred_alloc_comptime.create(sema.arena, undefined),
    );
}

fn zirAlloc(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const var_decl_src = inst_data.src();
    const var_ty = try sema.resolveType(block, ty_src, inst_data.operand);
    if (block.is_comptime) {
        return sema.analyzeComptimeAlloc(block, var_ty, 0);
    }
    const ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = var_ty,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });
    try sema.requireRuntimeBlock(block, var_decl_src);
    try sema.resolveTypeLayout(block, ty_src, var_ty);
    return block.addTy(.alloc, ptr_type);
}

fn zirAllocMut(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const var_decl_src = inst_data.src();
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const var_ty = try sema.resolveType(block, ty_src, inst_data.operand);
    if (block.is_comptime) {
        return sema.analyzeComptimeAlloc(block, var_ty, 0);
    }
    try sema.validateVarType(block, ty_src, var_ty, false);
    const ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = var_ty,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });
    try sema.requireRuntimeBlock(block, var_decl_src);
    try sema.resolveTypeLayout(block, ty_src, var_ty);
    return block.addTy(.alloc, ptr_type);
}

fn zirAllocInferred(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    inferred_alloc_ty: Type,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };
    sema.src = src;

    if (block.is_comptime) {
        return sema.addConstant(
            inferred_alloc_ty,
            try Value.Tag.inferred_alloc_comptime.create(sema.arena, undefined),
        );
    }

    // `Sema.addConstant` does not add the instruction to the block because it is
    // not needed in the case of constant values. However here, we plan to "downgrade"
    // to a normal instruction when we hit `resolve_inferred_alloc`. So we append
    // to the block even though it is currently a `.constant`.
    const result = try sema.addConstant(
        inferred_alloc_ty,
        try Value.Tag.inferred_alloc.create(sema.arena, .{}),
    );
    try sema.requireFunctionBlock(block, src);
    try block.instructions.append(sema.gpa, Air.refToIndex(result).?);
    return result;
}

fn zirResolveInferredAlloc(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const ptr = sema.resolveInst(inst_data.operand);
    const ptr_inst = Air.refToIndex(ptr).?;
    assert(sema.air_instructions.items(.tag)[ptr_inst] == .constant);
    const value_index = sema.air_instructions.items(.data)[ptr_inst].ty_pl.payload;
    const ptr_val = sema.air_values.items[value_index];
    const var_is_mut = switch (sema.typeOf(ptr).tag()) {
        .inferred_alloc_const => false,
        .inferred_alloc_mut => true,
        else => unreachable,
    };
    const target = sema.mod.getTarget();

    switch (ptr_val.tag()) {
        .inferred_alloc_comptime => {
            const iac = ptr_val.castTag(.inferred_alloc_comptime).?;
            const decl = iac.data;
            try sema.mod.declareDeclDependency(sema.owner_decl, decl);

            const final_elem_ty = try decl.ty.copy(sema.arena);
            const final_ptr_ty = try Type.ptr(sema.arena, .{
                .pointee_type = final_elem_ty,
                .@"addrspace" = target_util.defaultAddressSpace(target, .local),
            });
            const final_ptr_ty_inst = try sema.addType(final_ptr_ty);
            sema.air_instructions.items(.data)[ptr_inst].ty_pl.ty = final_ptr_ty_inst;

            if (var_is_mut) {
                sema.air_values.items[value_index] = try Value.Tag.decl_ref_mut.create(sema.arena, .{
                    .decl = decl,
                    .runtime_index = block.runtime_index,
                });
            } else {
                sema.air_values.items[value_index] = try Value.Tag.decl_ref.create(sema.arena, decl);
            }
        },
        .inferred_alloc => {
            const inferred_alloc = ptr_val.castTag(.inferred_alloc).?;
            const peer_inst_list = inferred_alloc.data.stored_inst_list.items;
            const final_elem_ty = try sema.resolvePeerTypes(block, ty_src, peer_inst_list, .none);

            try sema.requireRuntimeBlock(block, src);
            try sema.resolveTypeLayout(block, ty_src, final_elem_ty);

            if (var_is_mut) {
                try sema.validateVarType(block, ty_src, final_elem_ty, false);
            }
            // Change it to a normal alloc.
            const final_ptr_ty = try Type.ptr(sema.arena, .{
                .pointee_type = final_elem_ty,
                .@"addrspace" = target_util.defaultAddressSpace(target, .local),
            });
            sema.air_instructions.set(ptr_inst, .{
                .tag = .alloc,
                .data = .{ .ty = final_ptr_ty },
            });
        },
        else => unreachable,
    }
}

fn zirValidateStructInit(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const validate_inst = sema.code.instructions.items(.data)[inst].pl_node;
    const init_src = validate_inst.src();
    const validate_extra = sema.code.extraData(Zir.Inst.Block, validate_inst.payload_index);
    const instrs = sema.code.extra[validate_extra.end..][0..validate_extra.data.body_len];
    const field_ptr_data = sema.code.instructions.items(.data)[instrs[0]].pl_node;
    const field_ptr_extra = sema.code.extraData(Zir.Inst.Field, field_ptr_data.payload_index).data;
    const object_ptr = sema.resolveInst(field_ptr_extra.lhs);
    const agg_ty = sema.typeOf(object_ptr).childType();
    switch (agg_ty.zigTypeTag()) {
        .Struct => return sema.validateStructInit(
            block,
            agg_ty.castTag(.@"struct").?.data,
            init_src,
            instrs,
        ),
        .Union => return sema.validateUnionInit(
            block,
            agg_ty.cast(Type.Payload.Union).?.data,
            init_src,
            instrs,
            object_ptr,
        ),
        else => unreachable,
    }
}

fn validateUnionInit(
    sema: *Sema,
    block: *Block,
    union_obj: *Module.Union,
    init_src: LazySrcLoc,
    instrs: []const Zir.Inst.Index,
    union_ptr: Air.Inst.Ref,
) CompileError!void {
    if (instrs.len != 1) {
        // TODO add note for other field
        // TODO add note for union declared here
        return sema.fail(block, init_src, "only one union field can be active at once", .{});
    }

    const field_ptr = instrs[0];
    const field_ptr_data = sema.code.instructions.items(.data)[field_ptr].pl_node;
    const field_src: LazySrcLoc = .{ .node_offset_back2tok = field_ptr_data.src_node };
    const field_ptr_extra = sema.code.extraData(Zir.Inst.Field, field_ptr_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(field_ptr_extra.field_name_start);
    const field_index_big = union_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadUnionFieldAccess(block, union_obj, field_src, field_name);
    const field_index = @intCast(u32, field_index_big);

    // Handle the possibility of the union value being comptime-known.
    const union_ptr_inst = Air.refToIndex(sema.resolveInst(field_ptr_extra.lhs)).?;
    switch (sema.air_instructions.items(.tag)[union_ptr_inst]) {
        .constant => return, // In this case the tag has already been set. No validation to do.
        .bitcast => {
            // TODO here we need to go back and see if we need to convert the union
            // to a comptime-known value. In such case, we must delete all the instructions
            // added to the current block starting with the bitcast.
            // If the bitcast result ptr is an alloc, the alloc should be replaced with
            // a constant decl_ref.
            // Otherwise, the bitcast should be preserved and a store instruction should be
            // emitted to store the constant union value through the bitcast.
        },
        else => unreachable,
    }

    // Otherwise, we set the new union tag now.
    const new_tag = try sema.addConstant(
        union_obj.tag_ty,
        try Value.Tag.enum_field_index.create(sema.arena, field_index),
    );

    try sema.requireRuntimeBlock(block, init_src);
    _ = try block.addBinOp(.set_union_tag, union_ptr, new_tag);
}

fn validateStructInit(
    sema: *Sema,
    block: *Block,
    struct_obj: *Module.Struct,
    init_src: LazySrcLoc,
    instrs: []const Zir.Inst.Index,
) CompileError!void {
    const gpa = sema.gpa;

    // Maps field index to field_ptr index of where it was already initialized.
    const found_fields = try gpa.alloc(Zir.Inst.Index, struct_obj.fields.count());
    defer gpa.free(found_fields);
    mem.set(Zir.Inst.Index, found_fields, 0);

    for (instrs) |field_ptr| {
        const field_ptr_data = sema.code.instructions.items(.data)[field_ptr].pl_node;
        const field_src: LazySrcLoc = .{ .node_offset_back2tok = field_ptr_data.src_node };
        const field_ptr_extra = sema.code.extraData(Zir.Inst.Field, field_ptr_data.payload_index).data;
        const field_name = sema.code.nullTerminatedString(field_ptr_extra.field_name_start);
        const field_index = struct_obj.fields.getIndex(field_name) orelse
            return sema.failWithBadStructFieldAccess(block, struct_obj, field_src, field_name);
        if (found_fields[field_index] != 0) {
            const other_field_ptr = found_fields[field_index];
            const other_field_ptr_data = sema.code.instructions.items(.data)[other_field_ptr].pl_node;
            const other_field_src: LazySrcLoc = .{ .node_offset_back2tok = other_field_ptr_data.src_node };
            const msg = msg: {
                const msg = try sema.errMsg(block, field_src, "duplicate field", .{});
                errdefer msg.destroy(gpa);
                try sema.errNote(block, other_field_src, msg, "other field here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        found_fields[field_index] = field_ptr;
    }

    var root_msg: ?*Module.ErrorMsg = null;

    // TODO handle default struct field values
    for (found_fields) |field_ptr, i| {
        if (field_ptr != 0) continue;

        const field_name = struct_obj.fields.keys()[i];
        const template = "missing struct field: {s}";
        const args = .{field_name};
        if (root_msg) |msg| {
            try sema.errNote(block, init_src, msg, template, args);
        } else {
            root_msg = try sema.errMsg(block, init_src, template, args);
        }
    }
    if (root_msg) |msg| {
        const fqn = try struct_obj.getFullyQualifiedName(gpa);
        defer gpa.free(fqn);
        try sema.mod.errNoteNonLazy(
            struct_obj.srcLoc(),
            msg,
            "struct '{s}' declared here",
            .{fqn},
        );
        return sema.failWithOwnedErrorMsg(msg);
    }
}

fn zirValidateArrayInit(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const validate_inst = sema.code.instructions.items(.data)[inst].pl_node;
    const init_src = validate_inst.src();
    const validate_extra = sema.code.extraData(Zir.Inst.Block, validate_inst.payload_index);
    const instrs = sema.code.extra[validate_extra.end..][0..validate_extra.data.body_len];
    const elem_ptr_data = sema.code.instructions.items(.data)[instrs[0]].pl_node;
    const elem_ptr_extra = sema.code.extraData(Zir.Inst.ElemPtrImm, elem_ptr_data.payload_index).data;
    const array_ptr = sema.resolveInst(elem_ptr_extra.ptr);
    const array_ty = sema.typeOf(array_ptr).childType();
    const array_len = array_ty.arrayLen();

    if (instrs.len != array_len) {
        return sema.fail(block, init_src, "expected {d} array elements; found {d}", .{
            array_len, instrs.len,
        });
    }
}

fn failWithBadMemberAccess(
    sema: *Sema,
    block: *Block,
    agg_ty: Type,
    field_src: LazySrcLoc,
    field_name: []const u8,
) CompileError {
    const kw_name = switch (agg_ty.zigTypeTag()) {
        .Union => "union",
        .Struct => "struct",
        .Opaque => "opaque",
        .Enum => "enum",
        else => unreachable,
    };
    const msg = msg: {
        const msg = try sema.errMsg(block, field_src, "{s} '{}' has no member named '{s}'", .{
            kw_name, agg_ty, field_name,
        });
        errdefer msg.destroy(sema.gpa);
        try sema.addDeclaredHereNote(msg, agg_ty);
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

fn failWithBadStructFieldAccess(
    sema: *Sema,
    block: *Block,
    struct_obj: *Module.Struct,
    field_src: LazySrcLoc,
    field_name: []const u8,
) CompileError {
    const gpa = sema.gpa;

    const fqn = try struct_obj.getFullyQualifiedName(gpa);
    defer gpa.free(fqn);

    const msg = msg: {
        const msg = try sema.errMsg(
            block,
            field_src,
            "no field named '{s}' in struct '{s}'",
            .{ field_name, fqn },
        );
        errdefer msg.destroy(gpa);
        try sema.mod.errNoteNonLazy(struct_obj.srcLoc(), msg, "struct declared here", .{});
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

fn failWithBadUnionFieldAccess(
    sema: *Sema,
    block: *Block,
    union_obj: *Module.Union,
    field_src: LazySrcLoc,
    field_name: []const u8,
) CompileError {
    const gpa = sema.gpa;

    const fqn = try union_obj.getFullyQualifiedName(gpa);
    defer gpa.free(fqn);

    const msg = msg: {
        const msg = try sema.errMsg(
            block,
            field_src,
            "no field named '{s}' in union '{s}'",
            .{ field_name, fqn },
        );
        errdefer msg.destroy(gpa);
        try sema.mod.errNoteNonLazy(union_obj.srcLoc(), msg, "union declared here", .{});
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

fn addDeclaredHereNote(sema: *Sema, parent: *Module.ErrorMsg, decl_ty: Type) !void {
    const src_loc = decl_ty.declSrcLocOrNull() orelse return;
    const category = switch (decl_ty.zigTypeTag()) {
        .Union => "union",
        .Struct => "struct",
        .Enum => "enum",
        .Opaque => "opaque",
        .ErrorSet => "error set",
        else => unreachable,
    };
    try sema.mod.errNoteNonLazy(src_loc, parent, "{s} declared here", .{category});
}

fn zirStoreToBlockPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    if (bin_inst.lhs == .none) {
        // This is an elided instruction, but AstGen was not smart enough
        // to omit it.
        return;
    }
    const ptr = sema.resolveInst(bin_inst.lhs);
    const value = sema.resolveInst(bin_inst.rhs);
    const ptr_ty = try Type.ptr(sema.arena, .{
        .pointee_type = sema.typeOf(value),
        // TODO figure out which address space is appropriate here
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });
    // TODO detect when this store should be done at compile-time. For example,
    // if expressions should force it when the condition is compile-time known.
    const src: LazySrcLoc = .unneeded;
    try sema.requireRuntimeBlock(block, src);
    const bitcasted_ptr = try block.addBitCast(ptr_ty, ptr);
    return sema.storePtr(block, src, bitcasted_ptr, value);
}

fn zirStoreToInferredPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = sema.src;
    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const ptr = sema.resolveInst(bin_inst.lhs);
    const operand = sema.resolveInst(bin_inst.rhs);
    const operand_ty = sema.typeOf(operand);
    const ptr_inst = Air.refToIndex(ptr).?;
    assert(sema.air_instructions.items(.tag)[ptr_inst] == .constant);
    const air_datas = sema.air_instructions.items(.data);
    const ptr_val = sema.air_values.items[air_datas[ptr_inst].ty_pl.payload];

    if (ptr_val.castTag(.inferred_alloc_comptime)) |iac| {
        // There will be only one store_to_inferred_ptr because we are running at comptime.
        // The alloc will turn into a Decl.
        if (try sema.resolveMaybeUndefValAllowVariables(block, src, operand)) |operand_val| {
            if (operand_val.tag() == .variable) {
                return sema.failWithNeededComptime(block, src);
            }
            var anon_decl = try block.startAnonDecl();
            defer anon_decl.deinit();
            iac.data = try anon_decl.finish(
                try operand_ty.copy(anon_decl.arena()),
                try operand_val.copy(anon_decl.arena()),
            );
            return;
        } else {
            return sema.failWithNeededComptime(block, src);
        }
    }

    if (ptr_val.castTag(.inferred_alloc)) |inferred_alloc| {
        // Add the stored instruction to the set we will use to resolve peer types
        // for the inferred allocation.
        try inferred_alloc.data.stored_inst_list.append(sema.arena, operand);
        // Create a runtime bitcast instruction with exactly the type the pointer wants.
        const ptr_ty = try Type.ptr(sema.arena, .{
            .pointee_type = operand_ty,
            .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
        });
        const bitcasted_ptr = try block.addBitCast(ptr_ty, ptr);
        return sema.storePtr(block, src, bitcasted_ptr, operand);
    }
    unreachable;
}

fn zirSetEvalBranchQuota(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const quota = try sema.resolveAlreadyCoercedInt(block, src, inst_data.operand, u32);
    if (sema.branch_quota < quota)
        sema.branch_quota = quota;
}

fn zirStore(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const ptr = sema.resolveInst(bin_inst.lhs);
    const value = sema.resolveInst(bin_inst.rhs);
    return sema.storePtr(block, sema.src, ptr, value);
}

fn zirStoreNode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const ptr = sema.resolveInst(extra.lhs);
    const value = sema.resolveInst(extra.rhs);
    return sema.storePtr(block, src, ptr, value);
}

fn zirStr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_bytes = sema.code.instructions.items(.data)[inst].str.get(sema.code);

    // `zir_bytes` references memory inside the ZIR module, which can get deallocated
    // after semantic analysis is complete, for example in the case of the initialization
    // expression of a variable declaration. We need the memory to be in the new
    // anonymous Decl's arena.

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const bytes = try new_decl_arena.allocator.dupeZ(u8, zir_bytes);

    const decl_ty = try Type.Tag.array_u8_sentinel_0.create(&new_decl_arena.allocator, bytes.len);
    const decl_val = try Value.Tag.bytes.create(&new_decl_arena.allocator, bytes[0 .. bytes.len + 1]);

    const new_decl = try sema.mod.createAnonymousDecl(block, .{
        .ty = decl_ty,
        .val = decl_val,
    });
    errdefer sema.mod.abortAnonDecl(new_decl);
    try new_decl.finalizeNewArena(&new_decl_arena);
    return sema.analyzeDeclRef(new_decl);
}

fn zirInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const tracy = trace(@src());
    defer tracy.end();

    const int = sema.code.instructions.items(.data)[inst].int;
    return sema.addIntUnsigned(Type.initTag(.comptime_int), int);
}

fn zirIntBig(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const tracy = trace(@src());
    defer tracy.end();

    const arena = sema.arena;
    const int = sema.code.instructions.items(.data)[inst].str;
    const byte_count = int.len * @sizeOf(std.math.big.Limb);
    const limb_bytes = sema.code.string_bytes[int.start..][0..byte_count];
    const limbs = try arena.alloc(std.math.big.Limb, int.len);
    mem.copy(u8, mem.sliceAsBytes(limbs), limb_bytes);

    return sema.addConstant(
        Type.initTag(.comptime_int),
        try Value.Tag.int_big_positive.create(arena, limbs),
    );
}

fn zirFloat(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const arena = sema.arena;
    const number = sema.code.instructions.items(.data)[inst].float;
    return sema.addConstant(
        Type.initTag(.comptime_float),
        try Value.Tag.float_64.create(arena, number),
    );
}

fn zirFloat128(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Float128, inst_data.payload_index).data;
    const number = extra.get();
    return sema.addConstant(
        Type.initTag(.comptime_float),
        try Value.Tag.float_128.create(arena, number),
    );
}

fn zirCompileError(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const msg = try sema.resolveConstString(block, operand_src, inst_data.operand);
    return sema.fail(block, src, "{s}", .{msg});
}

fn zirCompileLog(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    var managed = sema.mod.compile_log_text.toManaged(sema.gpa);
    defer sema.mod.compile_log_text = managed.moveToUnmanaged();
    const writer = managed.writer();

    const extra = sema.code.extraData(Zir.Inst.NodeMultiOp, extended.operand);
    const src_node = extra.data.src_node;
    const src: LazySrcLoc = .{ .node_offset = src_node };
    const args = sema.code.refSlice(extra.end, extended.small);

    for (args) |arg_ref, i| {
        if (i != 0) try writer.print(", ", .{});

        const arg = sema.resolveInst(arg_ref);
        const arg_ty = sema.typeOf(arg);
        if (try sema.resolveMaybeUndefVal(block, src, arg)) |val| {
            try writer.print("@as({}, {})", .{ arg_ty, val });
        } else {
            try writer.print("@as({}, [runtime value])", .{arg_ty});
        }
    }
    try writer.print("\n", .{});

    const gop = try sema.mod.compile_log_decls.getOrPut(sema.gpa, sema.owner_decl);
    if (!gop.found_existing) {
        gop.value_ptr.* = src_node;
    }
    return Air.Inst.Ref.void_value;
}

fn zirPanic(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src: LazySrcLoc = inst_data.src();
    const msg_inst = sema.resolveInst(inst_data.operand);

    return sema.panicWithMsg(block, src, msg_inst);
}

fn zirLoop(sema: *Sema, parent_block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.Block, inst_data.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];
    const gpa = sema.gpa;

    // AIR expects a block outside the loop block too.
    // Reserve space for a Loop instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
    const loop_inst = block_inst + 1;
    try sema.air_instructions.ensureUnusedCapacity(gpa, 2);
    sema.air_instructions.appendAssumeCapacity(.{
        .tag = .block,
        .data = undefined,
    });
    sema.air_instructions.appendAssumeCapacity(.{
        .tag = .loop,
        .data = .{ .ty_pl = .{
            .ty = .noreturn_type,
            .payload = undefined,
        } },
    });
    var label: Block.Label = .{
        .zir_block = inst,
        .merges = .{
            .results = .{},
            .br_list = .{},
            .block_inst = block_inst,
        },
    };
    var child_block = parent_block.makeSubBlock();
    child_block.label = &label;
    child_block.runtime_cond = null;
    child_block.runtime_loop = src;
    child_block.runtime_index += 1;
    const merges = &child_block.label.?.merges;

    defer child_block.instructions.deinit(gpa);
    defer merges.results.deinit(gpa);
    defer merges.br_list.deinit(gpa);

    var loop_block = child_block.makeSubBlock();
    defer loop_block.instructions.deinit(gpa);

    _ = try sema.analyzeBody(&loop_block, body);

    try child_block.instructions.append(gpa, loop_inst);

    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        loop_block.instructions.items.len);
    sema.air_instructions.items(.data)[loop_inst].ty_pl.payload = sema.addExtraAssumeCapacity(
        Air.Block{ .body_len = @intCast(u32, loop_block.instructions.items.len) },
    );
    sema.air_extra.appendSliceAssumeCapacity(loop_block.instructions.items);
    return sema.analyzeBlockBody(parent_block, src, &child_block, merges);
}

fn zirCImport(sema: *Sema, parent_block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const pl_node = sema.code.instructions.items(.data)[inst].pl_node;
    const src = pl_node.src();
    const extra = sema.code.extraData(Zir.Inst.Block, pl_node.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];

    // we check this here to avoid undefined symbols
    if (!@import("build_options").have_llvm)
        return sema.fail(parent_block, src, "cannot do C import on Zig compiler not built with LLVM-extension", .{});

    var c_import_buf = std.ArrayList(u8).init(sema.gpa);
    defer c_import_buf.deinit();

    var child_block: Block = .{
        .parent = parent_block,
        .sema = sema,
        .src_decl = parent_block.src_decl,
        .namespace = parent_block.namespace,
        .wip_capture_scope = parent_block.wip_capture_scope,
        .instructions = .{},
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
        .c_import_buf = &c_import_buf,
    };
    defer child_block.instructions.deinit(sema.gpa);

    _ = try sema.analyzeBody(&child_block, body);

    const c_import_res = sema.mod.comp.cImport(c_import_buf.items) catch |err|
        return sema.fail(&child_block, src, "C import failed: {s}", .{@errorName(err)});

    if (c_import_res.errors.len != 0) {
        const msg = msg: {
            const msg = try sema.errMsg(&child_block, src, "C import failed", .{});
            errdefer msg.destroy(sema.gpa);

            if (!sema.mod.comp.bin_file.options.link_libc)
                try sema.errNote(&child_block, src, msg, "libc headers not available; compilation does not link against libc", .{});

            for (c_import_res.errors) |_| {
                // TODO integrate with LazySrcLoc
                // try sema.mod.errNoteNonLazy(.{}, msg, "{s}", .{clang_err.msg_ptr[0..clang_err.msg_len]});
                // if (clang_err.filename_ptr) |p| p[0..clang_err.filename_len] else "(no file)",
                // clang_err.line + 1,
                // clang_err.column + 1,
            }
            @import("clang.zig").Stage2ErrorMsg.delete(c_import_res.errors.ptr, c_import_res.errors.len);
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }
    const c_import_pkg = Package.create(
        sema.gpa,
        null,
        c_import_res.out_zig_path,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable, // we pass null for root_src_dir_path
    };
    const std_pkg = sema.mod.main_pkg.table.get("std").?;
    const builtin_pkg = sema.mod.main_pkg.table.get("builtin").?;
    try c_import_pkg.add(sema.gpa, "builtin", builtin_pkg);
    try c_import_pkg.add(sema.gpa, "std", std_pkg);

    const result = sema.mod.importPkg(c_import_pkg) catch |err|
        return sema.fail(&child_block, src, "C import failed: {s}", .{@errorName(err)});

    sema.mod.astGenFile(result.file) catch |err|
        return sema.fail(&child_block, src, "C import failed: {s}", .{@errorName(err)});

    try sema.mod.semaFile(result.file);
    const file_root_decl = result.file.root_decl.?;
    try sema.mod.declareDeclDependency(sema.owner_decl, file_root_decl);
    return sema.addConstant(file_root_decl.ty, file_root_decl.val);
}

fn zirSuspendBlock(sema: *Sema, parent_block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(parent_block, src, "TODO: implement Sema.zirSuspendBlock", .{});
}

fn zirBlock(
    sema: *Sema,
    parent_block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const pl_node = sema.code.instructions.items(.data)[inst].pl_node;
    const src = pl_node.src();
    const extra = sema.code.extraData(Zir.Inst.Block, pl_node.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];
    const gpa = sema.gpa;

    // Reserve space for a Block instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
    try sema.air_instructions.append(gpa, .{
        .tag = .block,
        .data = undefined,
    });

    var label: Block.Label = .{
        .zir_block = inst,
        .merges = .{
            .results = .{},
            .br_list = .{},
            .block_inst = block_inst,
        },
    };

    var child_block: Block = .{
        .parent = parent_block,
        .sema = sema,
        .src_decl = parent_block.src_decl,
        .namespace = parent_block.namespace,
        .wip_capture_scope = parent_block.wip_capture_scope,
        .instructions = .{},
        .label = &label,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
    };
    const merges = &child_block.label.?.merges;

    defer child_block.instructions.deinit(gpa);
    defer merges.results.deinit(gpa);
    defer merges.br_list.deinit(gpa);

    _ = try sema.analyzeBody(&child_block, body);

    return sema.analyzeBlockBody(parent_block, src, &child_block, merges);
}

fn resolveBlockBody(
    sema: *Sema,
    parent_block: *Block,
    src: LazySrcLoc,
    child_block: *Block,
    body: []const Zir.Inst.Index,
    merges: *Block.Merges,
) CompileError!Air.Inst.Ref {
    if (child_block.is_comptime) {
        return sema.resolveBody(child_block, body);
    } else {
        _ = try sema.analyzeBody(child_block, body);
        return sema.analyzeBlockBody(parent_block, src, child_block, merges);
    }
}

fn analyzeBlockBody(
    sema: *Sema,
    parent_block: *Block,
    src: LazySrcLoc,
    child_block: *Block,
    merges: *Block.Merges,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = sema.gpa;

    // Blocks must terminate with noreturn instruction.
    assert(child_block.instructions.items.len != 0);
    assert(sema.typeOf(Air.indexToRef(child_block.instructions.items[child_block.instructions.items.len - 1])).isNoReturn());

    if (merges.results.items.len == 0) {
        // No need for a block instruction. We can put the new instructions
        // directly into the parent block.
        try parent_block.instructions.appendSlice(gpa, child_block.instructions.items);
        return Air.indexToRef(child_block.instructions.items[child_block.instructions.items.len - 1]);
    }
    if (merges.results.items.len == 1) {
        const last_inst_index = child_block.instructions.items.len - 1;
        const last_inst = child_block.instructions.items[last_inst_index];
        if (sema.getBreakBlock(last_inst)) |br_block| {
            if (br_block == merges.block_inst) {
                // No need for a block instruction. We can put the new instructions directly
                // into the parent block. Here we omit the break instruction.
                const without_break = child_block.instructions.items[0..last_inst_index];
                try parent_block.instructions.appendSlice(gpa, without_break);
                return merges.results.items[0];
            }
        }
    }
    // It is impossible to have the number of results be > 1 in a comptime scope.
    assert(!child_block.is_comptime); // Should already got a compile error in the condbr condition.

    // Need to set the type and emit the Block instruction. This allows machine code generation
    // to emit a jump instruction to after the block when it encounters the break.
    try parent_block.instructions.append(gpa, merges.block_inst);
    const resolved_ty = try sema.resolvePeerTypes(parent_block, src, merges.results.items, .none);
    const ty_inst = try sema.addType(resolved_ty);
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        child_block.instructions.items.len);
    sema.air_instructions.items(.data)[merges.block_inst] = .{ .ty_pl = .{
        .ty = ty_inst,
        .payload = sema.addExtraAssumeCapacity(Air.Block{
            .body_len = @intCast(u32, child_block.instructions.items.len),
        }),
    } };
    sema.air_extra.appendSliceAssumeCapacity(child_block.instructions.items);
    // Now that the block has its type resolved, we need to go back into all the break
    // instructions, and insert type coercion on the operands.
    for (merges.br_list.items) |br| {
        const br_operand = sema.air_instructions.items(.data)[br].br.operand;
        const br_operand_src = src;
        const br_operand_ty = sema.typeOf(br_operand);
        if (br_operand_ty.eql(resolved_ty)) {
            // No type coercion needed.
            continue;
        }
        var coerce_block = parent_block.makeSubBlock();
        defer coerce_block.instructions.deinit(gpa);
        const coerced_operand = try sema.coerce(&coerce_block, resolved_ty, br_operand, br_operand_src);
        // If no instructions were produced, such as in the case of a coercion of a
        // constant value to a new type, we can simply point the br operand to it.
        if (coerce_block.instructions.items.len == 0) {
            sema.air_instructions.items(.data)[br].br.operand = coerced_operand;
            continue;
        }
        assert(coerce_block.instructions.items[coerce_block.instructions.items.len - 1] ==
            Air.refToIndex(coerced_operand).?);

        // Convert the br operand to a block.
        const br_operand_ty_ref = try sema.addType(br_operand_ty);
        try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
            coerce_block.instructions.items.len);
        try sema.air_instructions.ensureUnusedCapacity(gpa, 2);
        const sub_block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
        const sub_br_inst = sub_block_inst + 1;
        sema.air_instructions.items(.data)[br].br.operand = Air.indexToRef(sub_block_inst);
        sema.air_instructions.appendAssumeCapacity(.{
            .tag = .block,
            .data = .{ .ty_pl = .{
                .ty = br_operand_ty_ref,
                .payload = sema.addExtraAssumeCapacity(Air.Block{
                    .body_len = @intCast(u32, coerce_block.instructions.items.len),
                }),
            } },
        });
        sema.air_extra.appendSliceAssumeCapacity(coerce_block.instructions.items);
        sema.air_extra.appendAssumeCapacity(sub_br_inst);
        sema.air_instructions.appendAssumeCapacity(.{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = sub_block_inst,
                .operand = coerced_operand,
            } },
        });
    }
    return Air.indexToRef(merges.block_inst);
}

fn zirExport(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Export, inst_data.payload_index).data;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const options_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const decl_name = sema.code.nullTerminatedString(extra.decl_name);
    if (extra.namespace != .none) {
        return sema.fail(block, src, "TODO: implement exporting with field access", .{});
    }
    const decl = try sema.lookupIdentifier(block, operand_src, decl_name);
    const options = try sema.resolveExportOptions(block, options_src, extra.options);
    try sema.analyzeExport(block, src, options, decl);
}

fn zirExportValue(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.ExportValue, inst_data.payload_index).data;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const options_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand = try sema.resolveInstConst(block, operand_src, extra.operand);
    const options = try sema.resolveExportOptions(block, options_src, extra.options);
    const decl = switch (operand.val.tag()) {
        .function => operand.val.castTag(.function).?.data.owner_decl,
        else => return sema.fail(block, operand_src, "TODO implement exporting arbitrary Value objects", .{}), // TODO put this Value into an anonymous Decl and then export it.
    };
    try sema.analyzeExport(block, src, options, decl);
}

pub fn analyzeExport(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    borrowed_options: std.builtin.ExportOptions,
    exported_decl: *Decl,
) !void {
    const Export = Module.Export;
    const mod = sema.mod;

    try mod.ensureDeclAnalyzed(exported_decl);
    // TODO run the same checks as we do for C ABI struct fields
    switch (exported_decl.ty.zigTypeTag()) {
        .Fn, .Int, .Struct, .Array, .Float => {},
        else => return sema.fail(block, src, "unable to export type '{}'", .{exported_decl.ty}),
    }

    const gpa = mod.gpa;

    try mod.decl_exports.ensureUnusedCapacity(gpa, 1);
    try mod.export_owners.ensureUnusedCapacity(gpa, 1);

    const new_export = try gpa.create(Export);
    errdefer gpa.destroy(new_export);

    const symbol_name = try gpa.dupe(u8, borrowed_options.name);
    errdefer gpa.free(symbol_name);

    const section: ?[]const u8 = if (borrowed_options.section) |s| try gpa.dupe(u8, s) else null;
    errdefer if (section) |s| gpa.free(s);

    const src_decl = block.src_decl;
    const owner_decl = sema.owner_decl;

    log.debug("exporting Decl '{s}' as symbol '{s}' from Decl '{s}'", .{
        exported_decl.name, symbol_name, owner_decl.name,
    });

    new_export.* = .{
        .options = .{
            .name = symbol_name,
            .linkage = borrowed_options.linkage,
            .section = section,
        },
        .src = src,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = .{} },
            .macho => .{ .macho = .{} },
            .plan9 => .{ .plan9 = null },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = {} },
            .spirv => .{ .spirv = {} },
        },
        .owner_decl = owner_decl,
        .src_decl = src_decl,
        .exported_decl = exported_decl,
        .status = .in_progress,
    };

    // Add to export_owners table.
    const eo_gop = mod.export_owners.getOrPutAssumeCapacity(owner_decl);
    if (!eo_gop.found_existing) {
        eo_gop.value_ptr.* = &[0]*Export{};
    }
    eo_gop.value_ptr.* = try gpa.realloc(eo_gop.value_ptr.*, eo_gop.value_ptr.len + 1);
    eo_gop.value_ptr.*[eo_gop.value_ptr.len - 1] = new_export;
    errdefer eo_gop.value_ptr.* = gpa.shrink(eo_gop.value_ptr.*, eo_gop.value_ptr.len - 1);

    // Add to exported_decl table.
    const de_gop = mod.decl_exports.getOrPutAssumeCapacity(exported_decl);
    if (!de_gop.found_existing) {
        de_gop.value_ptr.* = &[0]*Export{};
    }
    de_gop.value_ptr.* = try gpa.realloc(de_gop.value_ptr.*, de_gop.value_ptr.len + 1);
    de_gop.value_ptr.*[de_gop.value_ptr.len - 1] = new_export;
    errdefer de_gop.value_ptr.* = gpa.shrink(de_gop.value_ptr.*, de_gop.value_ptr.len - 1);
}

fn zirSetAlignStack(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const src: LazySrcLoc = inst_data.src();
    const alignment = try sema.resolveAlign(block, operand_src, inst_data.operand);
    if (alignment > 256) {
        return sema.fail(block, src, "attempt to @setAlignStack({d}); maximum is 256", .{
            alignment,
        });
    }
    const func = sema.owner_func orelse
        return sema.fail(block, src, "@setAlignStack outside function body", .{});

    switch (func.owner_decl.ty.fnCallingConvention()) {
        .Naked => return sema.fail(block, src, "@setAlignStack in naked function", .{}),
        .Inline => return sema.fail(block, src, "@setAlignStack in inline function", .{}),
        else => {},
    }

    const gop = try sema.mod.align_stack_fns.getOrPut(sema.mod.gpa, func);
    if (gop.found_existing) {
        const msg = msg: {
            const msg = try sema.errMsg(block, src, "multiple @setAlignStack in the same function body", .{});
            errdefer msg.destroy(sema.gpa);
            try sema.errNote(block, src, msg, "other instance here", .{});
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }
    gop.value_ptr.* = .{ .alignment = alignment, .src = src };
}

fn zirSetCold(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const is_cold = try sema.resolveConstBool(block, operand_src, inst_data.operand);
    const func = sema.func orelse return; // does nothing outside a function
    func.is_cold = is_cold;
}

fn zirSetFloatMode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src: LazySrcLoc = inst_data.src();
    return sema.fail(block, src, "TODO: implement Sema.zirSetFloatMode", .{});
}

fn zirSetRuntimeSafety(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    block.want_safety = try sema.resolveConstBool(block, operand_src, inst_data.operand);
}

fn zirFence(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    if (block.is_comptime) return;

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const order_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const order = try sema.resolveAtomicOrder(block, order_src, inst_data.operand);

    if (@enumToInt(order) < @enumToInt(std.builtin.AtomicOrder.Acquire)) {
        return sema.fail(block, order_src, "atomic ordering must be Acquire or stricter", .{});
    }

    _ = try block.addInst(.{
        .tag = .fence,
        .data = .{ .fence = order },
    });
}

fn zirBreak(sema: *Sema, start_block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].@"break";
    const operand = sema.resolveInst(inst_data.operand);
    const zir_block = inst_data.block_inst;

    var block = start_block;
    while (true) {
        if (block.label) |label| {
            if (label.zir_block == zir_block) {
                const br_ref = try start_block.addBr(label.merges.block_inst, operand);
                try label.merges.results.append(sema.gpa, operand);
                try label.merges.br_list.append(sema.gpa, Air.refToIndex(br_ref).?);
                return inst;
            }
        }
        block = block.parent.?;
    }
}

fn zirDbgStmt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    // We do not set sema.src here because dbg_stmt instructions are only emitted for
    // ZIR code that possibly will need to generate runtime code. So error messages
    // and other source locations must not rely on sema.src being set from dbg_stmt
    // instructions.
    if (block.is_comptime) return;

    const inst_data = sema.code.instructions.items(.data)[inst].dbg_stmt;
    _ = try block.addInst(.{
        .tag = .dbg_stmt,
        .data = .{ .dbg_stmt = .{
            .line = inst_data.line,
            .column = inst_data.column,
        } },
    });
}

fn zirDeclRef(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const src = inst_data.src();
    const decl_name = inst_data.get(sema.code);
    const decl = try sema.lookupIdentifier(block, src, decl_name);
    return sema.analyzeDeclRef(decl);
}

fn zirDeclVal(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const src = inst_data.src();
    const decl_name = inst_data.get(sema.code);
    const decl = try sema.lookupIdentifier(block, src, decl_name);
    return sema.analyzeDeclVal(block, src, decl);
}

fn lookupIdentifier(sema: *Sema, block: *Block, src: LazySrcLoc, name: []const u8) !*Decl {
    var namespace = block.namespace;
    while (true) {
        if (try sema.lookupInNamespace(block, src, namespace, name, false)) |decl| {
            return decl;
        }
        namespace = namespace.parent orelse break;
    }
    unreachable; // AstGen detects use of undeclared identifier errors.
}

/// This looks up a member of a specific namespace. It is affected by `usingnamespace` but
/// only for ones in the specified namespace.
fn lookupInNamespace(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    namespace: *Namespace,
    ident_name: []const u8,
    observe_usingnamespace: bool,
) CompileError!?*Decl {
    const mod = sema.mod;

    const namespace_decl = namespace.getDecl();
    if (namespace_decl.analysis == .file_failure) {
        try mod.declareDeclDependency(sema.owner_decl, namespace_decl);
        return error.AnalysisFail;
    }

    if (observe_usingnamespace and namespace.usingnamespace_set.count() != 0) {
        const src_file = block.namespace.file_scope;

        const gpa = sema.gpa;
        var checked_namespaces: std.AutoArrayHashMapUnmanaged(*Namespace, void) = .{};
        defer checked_namespaces.deinit(gpa);

        // Keep track of name conflicts for error notes.
        var candidates: std.ArrayListUnmanaged(*Decl) = .{};
        defer candidates.deinit(gpa);

        try checked_namespaces.put(gpa, namespace, {});
        var check_i: usize = 0;

        while (check_i < checked_namespaces.count()) : (check_i += 1) {
            const check_ns = checked_namespaces.keys()[check_i];
            if (check_ns.decls.get(ident_name)) |decl| {
                // Skip decls which are not marked pub, which are in a different
                // file than the `a.b`/`@hasDecl` syntax.
                if (decl.is_pub or src_file == decl.getFileScope()) {
                    try candidates.append(gpa, decl);
                }
            }
            var it = check_ns.usingnamespace_set.iterator();
            while (it.next()) |entry| {
                const sub_usingnamespace_decl = entry.key_ptr.*;
                const sub_is_pub = entry.value_ptr.*;
                if (!sub_is_pub and src_file != sub_usingnamespace_decl.getFileScope()) {
                    // Skip usingnamespace decls which are not marked pub, which are in
                    // a different file than the `a.b`/`@hasDecl` syntax.
                    continue;
                }
                try sema.ensureDeclAnalyzed(sub_usingnamespace_decl);
                const ns_ty = sub_usingnamespace_decl.val.castTag(.ty).?.data;
                const sub_ns = ns_ty.getNamespace().?;
                try checked_namespaces.put(gpa, sub_ns, {});
            }
        }

        switch (candidates.items.len) {
            0 => {},
            1 => {
                const decl = candidates.items[0];
                try mod.declareDeclDependency(sema.owner_decl, decl);
                return decl;
            },
            else => {
                const msg = msg: {
                    const msg = try sema.errMsg(block, src, "ambiguous reference", .{});
                    errdefer msg.destroy(gpa);
                    for (candidates.items) |candidate| {
                        const src_loc = candidate.srcLoc();
                        try mod.errNoteNonLazy(src_loc, msg, "declared here", .{});
                    }
                    break :msg msg;
                };
                return sema.failWithOwnedErrorMsg(msg);
            },
        }
    } else if (namespace.decls.get(ident_name)) |decl| {
        try mod.declareDeclDependency(sema.owner_decl, decl);
        return decl;
    }

    log.debug("{*} ({s}) depends on non-existence of '{s}' in {*} ({s})", .{
        sema.owner_decl, sema.owner_decl.name, ident_name, namespace_decl, namespace_decl.name,
    });
    // TODO This dependency is too strong. Really, it should only be a dependency
    // on the non-existence of `ident_name` in the namespace. We can lessen the number of
    // outdated declarations by making this dependency more sophisticated.
    try mod.declareDeclDependency(sema.owner_decl, namespace_decl);
    return null;
}

fn zirCall(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const func_src: LazySrcLoc = .{ .node_offset_call_func = inst_data.src_node };
    const call_src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.Call, inst_data.payload_index);
    const args = sema.code.refSlice(extra.end, extra.data.flags.args_len);

    const modifier = @intToEnum(std.builtin.CallOptions.Modifier, extra.data.flags.packed_modifier);
    const ensure_result_used = extra.data.flags.ensure_result_used;

    var func = sema.resolveInst(extra.data.callee);
    var resolved_args: []Air.Inst.Ref = undefined;

    const func_type = sema.typeOf(func);

    // Desugar bound functions here
    if (func_type.tag() == .bound_fn) {
        const bound_func = try sema.resolveValue(block, func_src, func);
        const bound_data = &bound_func.cast(Value.Payload.BoundFn).?.data;
        func = bound_data.func_inst;
        resolved_args = try sema.arena.alloc(Air.Inst.Ref, args.len + 1);
        resolved_args[0] = bound_data.arg0_inst;
        for (args) |zir_arg, i| {
            resolved_args[i + 1] = sema.resolveInst(zir_arg);
        }
    } else {
        resolved_args = try sema.arena.alloc(Air.Inst.Ref, args.len);
        for (args) |zir_arg, i| {
            resolved_args[i] = sema.resolveInst(zir_arg);
        }
    }

    return sema.analyzeCall(block, func, func_src, call_src, modifier, ensure_result_used, resolved_args);
}

const GenericCallAdapter = struct {
    generic_fn: *Module.Fn,
    precomputed_hash: u64,
    func_ty_info: Type.Payload.Function.Data,
    comptime_tvs: []const TypedValue,

    pub fn eql(ctx: @This(), adapted_key: void, other_key: *Module.Fn) bool {
        _ = adapted_key;
        // The generic function Decl is guaranteed to be the first dependency
        // of each of its instantiations.
        const generic_owner_decl = other_key.owner_decl.dependencies.keys()[0];
        if (ctx.generic_fn.owner_decl != generic_owner_decl) return false;

        const other_comptime_args = other_key.comptime_args.?;
        for (other_comptime_args[0..ctx.func_ty_info.param_types.len]) |other_arg, i| {
            if (other_arg.ty.tag() != .generic_poison) {
                // anytype parameter
                if (!other_arg.ty.eql(ctx.comptime_tvs[i].ty)) {
                    return false;
                }
            }
            if (other_arg.val.tag() != .generic_poison) {
                // comptime parameter
                if (ctx.comptime_tvs[i].val.tag() == .generic_poison) {
                    // No match because the instantiation has a comptime parameter
                    // but the callsite does not.
                    return false;
                }
                if (!other_arg.val.eql(ctx.comptime_tvs[i].val, other_arg.ty)) {
                    return false;
                }
            }
        }
        return true;
    }

    /// The implementation of the hash is in semantic analysis of function calls, so
    /// that any errors when computing the hash can be properly reported.
    pub fn hash(ctx: @This(), adapted_key: void) u64 {
        _ = adapted_key;
        return ctx.precomputed_hash;
    }
};

const GenericRemoveAdapter = struct {
    precomputed_hash: u64,

    pub fn eql(ctx: @This(), adapted_key: *Module.Fn, other_key: *Module.Fn) bool {
        _ = ctx;
        return adapted_key == other_key;
    }

    /// The implementation of the hash is in semantic analysis of function calls, so
    /// that any errors when computing the hash can be properly reported.
    pub fn hash(ctx: @This(), adapted_key: *Module.Fn) u64 {
        _ = adapted_key;
        return ctx.precomputed_hash;
    }
};

fn analyzeCall(
    sema: *Sema,
    block: *Block,
    func: Air.Inst.Ref,
    func_src: LazySrcLoc,
    call_src: LazySrcLoc,
    modifier: std.builtin.CallOptions.Modifier,
    ensure_result_used: bool,
    uncasted_args: []const Air.Inst.Ref,
) CompileError!Air.Inst.Ref {
    const mod = sema.mod;

    const callee_ty = sema.typeOf(func);
    const func_ty = func_ty: {
        switch (callee_ty.zigTypeTag()) {
            .Fn => break :func_ty callee_ty,
            .Pointer => {
                const ptr_info = callee_ty.ptrInfo().data;
                if (ptr_info.size == .One and ptr_info.pointee_type.zigTypeTag() == .Fn) {
                    break :func_ty ptr_info.pointee_type;
                }
            },
            else => {},
        }
        return sema.fail(block, func_src, "type '{}' not a function", .{callee_ty});
    };

    const func_ty_info = func_ty.fnInfo();
    const cc = func_ty_info.cc;
    if (cc == .Naked) {
        // TODO add error note: declared here
        return sema.fail(
            block,
            func_src,
            "unable to call function with naked calling convention",
            .{},
        );
    }
    const fn_params_len = func_ty_info.param_types.len;
    if (func_ty_info.is_var_args) {
        assert(cc == .C);
        if (uncasted_args.len < fn_params_len) {
            // TODO add error note: declared here
            return sema.fail(
                block,
                func_src,
                "expected at least {d} argument(s), found {d}",
                .{ fn_params_len, uncasted_args.len },
            );
        }
    } else if (fn_params_len != uncasted_args.len) {
        // TODO add error note: declared here
        return sema.fail(
            block,
            func_src,
            "expected {d} argument(s), found {d}",
            .{ fn_params_len, uncasted_args.len },
        );
    }

    switch (modifier) {
        .auto,
        .always_inline,
        .compile_time,
        => {},

        .async_kw,
        .never_tail,
        .never_inline,
        .no_async,
        .always_tail,
        => return sema.fail(block, call_src, "TODO implement call with modifier {}", .{
            modifier,
        }),
    }

    const gpa = sema.gpa;

    const is_comptime_call = block.is_comptime or modifier == .compile_time or
        func_ty_info.return_type.requiresComptime();
    const is_inline_call = is_comptime_call or modifier == .always_inline or
        func_ty_info.cc == .Inline;
    const result: Air.Inst.Ref = if (is_inline_call) res: {
        const func_val = try sema.resolveConstValue(block, func_src, func);
        const module_fn = switch (func_val.tag()) {
            .decl_ref => func_val.castTag(.decl_ref).?.data.val.castTag(.function).?.data,
            .function => func_val.castTag(.function).?.data,
            .extern_fn => return sema.fail(block, call_src, "{s} call of extern function", .{
                @as([]const u8, if (is_comptime_call) "comptime" else "inline"),
            }),
            else => unreachable,
        };

        // Analyze the ZIR. The same ZIR gets analyzed into a runtime function
        // or an inlined call depending on what union tag the `label` field is
        // set to in the `Block`.
        // This block instruction will be used to capture the return value from the
        // inlined function.
        const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
        try sema.air_instructions.append(gpa, .{
            .tag = .block,
            .data = undefined,
        });
        // This one is shared among sub-blocks within the same callee, but not
        // shared among the entire inline/comptime call stack.
        var inlining: Block.Inlining = .{
            .comptime_result = undefined,
            .merges = .{
                .results = .{},
                .br_list = .{},
                .block_inst = block_inst,
            },
        };
        // In order to save a bit of stack space, directly modify Sema rather
        // than create a child one.
        const parent_zir = sema.code;
        sema.code = module_fn.owner_decl.getFileScope().zir;
        defer sema.code = parent_zir;

        const parent_inst_map = sema.inst_map;
        sema.inst_map = .{};
        defer {
            sema.inst_map.deinit(gpa);
            sema.inst_map = parent_inst_map;
        }

        const parent_func = sema.func;
        sema.func = module_fn;
        defer sema.func = parent_func;

        var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, module_fn.owner_decl.src_scope);
        defer wip_captures.deinit();

        var child_block: Block = .{
            .parent = null,
            .sema = sema,
            .src_decl = module_fn.owner_decl,
            .namespace = module_fn.owner_decl.src_namespace,
            .wip_capture_scope = wip_captures.scope,
            .instructions = .{},
            .label = null,
            .inlining = &inlining,
            .is_comptime = is_comptime_call,
        };

        const merges = &child_block.inlining.?.merges;

        defer child_block.instructions.deinit(gpa);
        defer merges.results.deinit(gpa);
        defer merges.br_list.deinit(gpa);

        // If it's a comptime function call, we need to memoize it as long as no external
        // comptime memory is mutated.
        var memoized_call_key: Module.MemoizedCall.Key = undefined;
        var delete_memoized_call_key = false;
        defer if (delete_memoized_call_key) gpa.free(memoized_call_key.args);
        if (is_comptime_call) {
            memoized_call_key = .{
                .func = module_fn,
                .args = try gpa.alloc(TypedValue, func_ty_info.param_types.len),
            };
            delete_memoized_call_key = true;
        }

        try sema.emitBackwardBranch(&child_block, call_src);

        // This will have return instructions analyzed as break instructions to
        // the block_inst above. Here we are performing "comptime/inline semantic analysis"
        // for a function body, which means we must map the parameter ZIR instructions to
        // the AIR instructions of the callsite. The callee could be a generic function
        // which means its parameter type expressions must be resolved in order and used
        // to successively coerce the arguments.
        const fn_info = sema.code.getFnInfo(module_fn.zir_body_inst);
        const zir_tags = sema.code.instructions.items(.tag);
        var arg_i: usize = 0;
        for (fn_info.param_body) |inst| switch (zir_tags[inst]) {
            .param, .param_comptime => {
                // Evaluate the parameter type expression now that previous ones have
                // been mapped, and coerce the corresponding argument to it.
                const pl_tok = sema.code.instructions.items(.data)[inst].pl_tok;
                const param_src = pl_tok.src();
                const extra = sema.code.extraData(Zir.Inst.Param, pl_tok.payload_index);
                const param_body = sema.code.extra[extra.end..][0..extra.data.body_len];
                const param_ty_inst = try sema.resolveBody(&child_block, param_body);
                const param_ty = try sema.analyzeAsType(&child_block, param_src, param_ty_inst);
                const arg_src = call_src; // TODO: better source location
                const casted_arg = try sema.coerce(&child_block, param_ty, uncasted_args[arg_i], arg_src);
                try sema.inst_map.putNoClobber(gpa, inst, casted_arg);

                if (is_comptime_call) {
                    const arg_val = try sema.resolveConstMaybeUndefVal(&child_block, arg_src, casted_arg);
                    memoized_call_key.args[arg_i] = .{
                        .ty = param_ty,
                        .val = arg_val,
                    };
                }

                arg_i += 1;
                continue;
            },
            .param_anytype, .param_anytype_comptime => {
                // No coercion needed.
                const uncasted_arg = uncasted_args[arg_i];
                try sema.inst_map.putNoClobber(gpa, inst, uncasted_arg);

                if (is_comptime_call) {
                    const arg_src = call_src; // TODO: better source location
                    const arg_val = try sema.resolveConstMaybeUndefVal(&child_block, arg_src, uncasted_arg);
                    memoized_call_key.args[arg_i] = .{
                        .ty = sema.typeOf(uncasted_arg),
                        .val = arg_val,
                    };
                }

                arg_i += 1;
                continue;
            },
            else => continue,
        };

        // In case it is a generic function with an expression for the return type that depends
        // on parameters, we must now do the same for the return type as we just did with
        // each of the parameters, resolving the return type and providing it to the child
        // `Sema` so that it can be used for the `ret_ptr` instruction.
        const ret_ty_inst = try sema.resolveBody(&child_block, fn_info.ret_ty_body);
        const ret_ty_src = func_src; // TODO better source location
        const bare_return_type = try sema.analyzeAsType(&child_block, ret_ty_src, ret_ty_inst);
        // If the function has an inferred error set, `bare_return_type` is the payload type only.
        const fn_ret_ty = blk: {
            // TODO instead of reusing the function's inferred error set, this code should
            // create a temporary error set which is used for the comptime/inline function
            // call alone, independent from the runtime instantiation.
            if (func_ty_info.return_type.castTag(.error_union)) |payload| {
                const error_set_ty = payload.data.error_set;
                break :blk try Type.Tag.error_union.create(sema.arena, .{
                    .error_set = error_set_ty,
                    .payload = bare_return_type,
                });
            }
            break :blk bare_return_type;
        };
        const parent_fn_ret_ty = sema.fn_ret_ty;
        sema.fn_ret_ty = fn_ret_ty;
        defer sema.fn_ret_ty = parent_fn_ret_ty;

        // This `res2` is here instead of directly breaking from `res` due to a stage1
        // bug generating invalid LLVM IR.
        const res2: Air.Inst.Ref = res2: {
            if (is_comptime_call) {
                if (mod.memoized_calls.get(memoized_call_key)) |result| {
                    const ty_inst = try sema.addType(fn_ret_ty);
                    try sema.air_values.append(gpa, result.val);
                    sema.air_instructions.set(block_inst, .{
                        .tag = .constant,
                        .data = .{ .ty_pl = .{
                            .ty = ty_inst,
                            .payload = @intCast(u32, sema.air_values.items.len - 1),
                        } },
                    });
                    break :res2 Air.indexToRef(block_inst);
                }
            }

            const result = result: {
                _ = sema.analyzeBody(&child_block, fn_info.body) catch |err| switch (err) {
                    error.ComptimeReturn => break :result inlining.comptime_result,
                    else => |e| return e,
                };
                break :result try sema.analyzeBlockBody(block, call_src, &child_block, merges);
            };

            if (is_comptime_call) {
                const result_val = try sema.resolveConstMaybeUndefVal(block, call_src, result);

                // TODO: check whether any external comptime memory was mutated by the
                // comptime function call. If so, then do not memoize the call here.
                // TODO: re-evaluate whether memoized_calls needs its own arena. I think
                // it should be fine to use the Decl arena for the function.
                {
                    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
                    errdefer arena_allocator.deinit();
                    const arena = &arena_allocator.allocator;

                    for (memoized_call_key.args) |*arg| {
                        arg.* = try arg.*.copy(arena);
                    }

                    try mod.memoized_calls.put(gpa, memoized_call_key, .{
                        .val = try result_val.copy(arena),
                        .arena = arena_allocator.state,
                    });
                    delete_memoized_call_key = false;
                }
            }

            break :res2 result;
        };

        try wip_captures.finalize();

        break :res res2;
    } else if (func_ty_info.is_generic) res: {
        const func_val = try sema.resolveConstValue(block, func_src, func);
        const module_fn = switch (func_val.tag()) {
            .function => func_val.castTag(.function).?.data,
            .decl_ref => func_val.castTag(.decl_ref).?.data.val.castTag(.function).?.data,
            else => unreachable,
        };
        // Check the Module's generic function map with an adapted context, so that we
        // can match against `uncasted_args` rather than doing the work below to create a
        // generic Scope only to junk it if it matches an existing instantiation.
        const namespace = module_fn.owner_decl.src_namespace;
        const fn_zir = namespace.file_scope.zir;
        const fn_info = fn_zir.getFnInfo(module_fn.zir_body_inst);
        const zir_tags = fn_zir.instructions.items(.tag);

        // This hash must match `Module.MonomorphedFuncsContext.hash`.
        // For parameters explicitly marked comptime and simple parameter type expressions,
        // we know whether a parameter is elided from a monomorphed function, and can
        // use it in the hash here. However, for parameter type expressions that are not
        // explicitly marked comptime and rely on previous parameter comptime values, we
        // don't find out until after generating a monomorphed function whether the parameter
        // type ended up being a "must-be-comptime-known" type.
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, @ptrToInt(module_fn));

        const comptime_tvs = try sema.arena.alloc(TypedValue, func_ty_info.param_types.len);

        for (func_ty_info.param_types) |param_ty, i| {
            const is_comptime = func_ty_info.paramIsComptime(i);
            if (is_comptime) {
                const arg_src = call_src; // TODO better source location
                const casted_arg = try sema.coerce(block, param_ty, uncasted_args[i], arg_src);
                if (try sema.resolveMaybeUndefVal(block, arg_src, casted_arg)) |arg_val| {
                    if (param_ty.tag() != .generic_poison) {
                        arg_val.hash(param_ty, &hasher);
                    }
                    comptime_tvs[i] = .{
                        // This will be different than `param_ty` in the case of `generic_poison`.
                        .ty = sema.typeOf(casted_arg),
                        .val = arg_val,
                    };
                } else {
                    return sema.failWithNeededComptime(block, arg_src);
                }
            } else {
                comptime_tvs[i] = .{
                    .ty = sema.typeOf(uncasted_args[i]),
                    .val = Value.initTag(.generic_poison),
                };
            }
        }

        const precomputed_hash = hasher.final();

        const adapter: GenericCallAdapter = .{
            .generic_fn = module_fn,
            .precomputed_hash = precomputed_hash,
            .func_ty_info = func_ty_info,
            .comptime_tvs = comptime_tvs,
        };
        const gop = try mod.monomorphed_funcs.getOrPutAdapted(gpa, {}, adapter);
        if (gop.found_existing) {
            const callee_func = gop.key_ptr.*;
            break :res try sema.finishGenericCall(
                block,
                call_src,
                callee_func,
                func_src,
                uncasted_args,
                fn_info,
                zir_tags,
            );
        }
        const new_module_func = try gpa.create(Module.Fn);
        gop.key_ptr.* = new_module_func;
        {
            errdefer gpa.destroy(new_module_func);
            const remove_adapter: GenericRemoveAdapter = .{
                .precomputed_hash = precomputed_hash,
            };
            errdefer assert(mod.monomorphed_funcs.removeAdapted(new_module_func, remove_adapter));

            try namespace.anon_decls.ensureUnusedCapacity(gpa, 1);

            // Create a Decl for the new function.
            const src_decl = namespace.getDecl();
            // TODO better names for generic function instantiations
            const name_index = mod.getNextAnonNameIndex();
            const decl_name = try std.fmt.allocPrintZ(gpa, "{s}__anon_{d}", .{
                module_fn.owner_decl.name, name_index,
            });
            const new_decl = try mod.allocateNewDecl(decl_name, namespace, module_fn.owner_decl.src_node, src_decl.src_scope);
            new_decl.src_line = module_fn.owner_decl.src_line;
            new_decl.is_pub = module_fn.owner_decl.is_pub;
            new_decl.is_exported = module_fn.owner_decl.is_exported;
            new_decl.has_align = module_fn.owner_decl.has_align;
            new_decl.has_linksection_or_addrspace = module_fn.owner_decl.has_linksection_or_addrspace;
            new_decl.@"addrspace" = module_fn.owner_decl.@"addrspace";
            new_decl.zir_decl_index = module_fn.owner_decl.zir_decl_index;
            new_decl.alive = true; // This Decl is called at runtime.
            new_decl.has_tv = true;
            new_decl.owns_tv = true;
            new_decl.analysis = .in_progress;
            new_decl.generation = mod.generation;

            namespace.anon_decls.putAssumeCapacityNoClobber(new_decl, {});

            // The generic function Decl is guaranteed to be the first dependency
            // of each of its instantiations.
            assert(new_decl.dependencies.keys().len == 0);
            try mod.declareDeclDependency(new_decl, module_fn.owner_decl);

            var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
            errdefer new_decl_arena.deinit();

            // Re-run the block that creates the function, with the comptime parameters
            // pre-populated inside `inst_map`. This causes `param_comptime` and
            // `param_anytype_comptime` ZIR instructions to be ignored, resulting in a
            // new, monomorphized function, with the comptime parameters elided.
            var child_sema: Sema = .{
                .mod = mod,
                .gpa = gpa,
                .arena = sema.arena,
                .perm_arena = &new_decl_arena.allocator,
                .code = fn_zir,
                .owner_decl = new_decl,
                .func = null,
                .fn_ret_ty = Type.void,
                .owner_func = null,
                .comptime_args = try new_decl_arena.allocator.alloc(TypedValue, uncasted_args.len),
                .comptime_args_fn_inst = module_fn.zir_body_inst,
                .preallocated_new_func = new_module_func,
            };
            defer child_sema.deinit();

            var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, new_decl.src_scope);
            defer wip_captures.deinit();

            var child_block: Block = .{
                .parent = null,
                .sema = &child_sema,
                .src_decl = new_decl,
                .namespace = namespace,
                .wip_capture_scope = wip_captures.scope,
                .instructions = .{},
                .inlining = null,
                .is_comptime = true,
            };
            defer {
                child_block.instructions.deinit(gpa);
                child_block.params.deinit(gpa);
            }

            try child_sema.inst_map.ensureUnusedCapacity(gpa, @intCast(u32, uncasted_args.len));
            var arg_i: usize = 0;
            for (fn_info.param_body) |inst| {
                var is_comptime = false;
                var is_anytype = false;
                switch (zir_tags[inst]) {
                    .param => {
                        is_comptime = func_ty_info.paramIsComptime(arg_i);
                    },
                    .param_comptime => {
                        is_comptime = true;
                    },
                    .param_anytype => {
                        is_anytype = true;
                        is_comptime = func_ty_info.paramIsComptime(arg_i);
                    },
                    .param_anytype_comptime => {
                        is_anytype = true;
                        is_comptime = true;
                    },
                    else => continue,
                }
                const arg_src = call_src; // TODO: better source location
                const arg = uncasted_args[arg_i];
                if (is_comptime) {
                    if (try sema.resolveMaybeUndefVal(block, arg_src, arg)) |arg_val| {
                        const child_arg = try child_sema.addConstant(sema.typeOf(arg), arg_val);
                        child_sema.inst_map.putAssumeCapacityNoClobber(inst, child_arg);
                    } else {
                        return sema.failWithNeededComptime(block, arg_src);
                    }
                } else if (is_anytype) {
                    // We insert into the map an instruction which is runtime-known
                    // but has the type of the argument.
                    const child_arg = try child_block.addArg(sema.typeOf(arg), 0);
                    child_sema.inst_map.putAssumeCapacityNoClobber(inst, child_arg);
                }
                arg_i += 1;
            }
            const new_func_inst = child_sema.resolveBody(&child_block, fn_info.param_body) catch |err| {
                // TODO look up the compile error that happened here and attach a note to it
                // pointing here, at the generic instantiation callsite.
                if (sema.owner_func) |owner_func| {
                    owner_func.state = .dependency_failure;
                } else {
                    sema.owner_decl.analysis = .dependency_failure;
                }
                return err;
            };
            const new_func_val = child_sema.resolveConstValue(&child_block, .unneeded, new_func_inst) catch unreachable;
            const new_func = new_func_val.castTag(.function).?.data;
            assert(new_func == new_module_func);

            arg_i = 0;
            for (fn_info.param_body) |inst| {
                switch (zir_tags[inst]) {
                    .param_comptime, .param_anytype_comptime, .param, .param_anytype => {},
                    else => continue,
                }
                const arg = child_sema.inst_map.get(inst).?;
                const copied_arg_ty = try child_sema.typeOf(arg).copy(&new_decl_arena.allocator);
                if (child_sema.resolveMaybeUndefValAllowVariables(
                    &child_block,
                    .unneeded,
                    arg,
                ) catch unreachable) |arg_val| {
                    child_sema.comptime_args[arg_i] = .{
                        .ty = copied_arg_ty,
                        .val = try arg_val.copy(&new_decl_arena.allocator),
                    };
                } else {
                    child_sema.comptime_args[arg_i] = .{
                        .ty = copied_arg_ty,
                        .val = Value.initTag(.generic_poison),
                    };
                }

                arg_i += 1;
            }

            try wip_captures.finalize();

            // Populate the Decl ty/val with the function and its type.
            new_decl.ty = try child_sema.typeOf(new_func_inst).copy(&new_decl_arena.allocator);
            new_decl.val = try Value.Tag.function.create(&new_decl_arena.allocator, new_func);
            new_decl.analysis = .complete;

            log.debug("generic function '{s}' instantiated with type {}", .{
                new_decl.name, new_decl.ty,
            });
            assert(!new_decl.ty.fnInfo().is_generic);

            // Queue up a `codegen_func` work item for the new Fn. The `comptime_args` field
            // will be populated, ensuring it will have `analyzeBody` called with the ZIR
            // parameters mapped appropriately.
            try mod.comp.bin_file.allocateDeclIndexes(new_decl);
            try mod.comp.work_queue.writeItem(.{ .codegen_func = new_func });

            try new_decl.finalizeNewArena(&new_decl_arena);
        }

        break :res try sema.finishGenericCall(
            block,
            call_src,
            new_module_func,
            func_src,
            uncasted_args,
            fn_info,
            zir_tags,
        );
    } else res: {
        try sema.requireRuntimeBlock(block, call_src);

        const args = try sema.arena.alloc(Air.Inst.Ref, uncasted_args.len);
        for (uncasted_args) |uncasted_arg, i| {
            const arg_src = call_src; // TODO: better source location
            if (i < fn_params_len) {
                const param_ty = func_ty.fnParamType(i);
                try sema.resolveTypeLayout(block, arg_src, param_ty);
                args[i] = try sema.coerce(block, param_ty, uncasted_arg, arg_src);
            } else {
                args[i] = uncasted_arg;
            }
        }

        try sema.resolveTypeLayout(block, call_src, func_ty_info.return_type);

        try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Call).Struct.fields.len +
            args.len);
        const func_inst = try block.addInst(.{
            .tag = .call,
            .data = .{ .pl_op = .{
                .operand = func,
                .payload = sema.addExtraAssumeCapacity(Air.Call{
                    .args_len = @intCast(u32, args.len),
                }),
            } },
        });
        sema.appendRefsAssumeCapacity(args);
        break :res func_inst;
    };

    if (ensure_result_used) {
        try sema.ensureResultUsed(block, result, call_src);
    }
    return result;
}

fn finishGenericCall(
    sema: *Sema,
    block: *Block,
    call_src: LazySrcLoc,
    callee: *Module.Fn,
    func_src: LazySrcLoc,
    uncasted_args: []const Air.Inst.Ref,
    fn_info: Zir.FnInfo,
    zir_tags: []const Zir.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const callee_inst = try sema.analyzeDeclVal(block, func_src, callee.owner_decl);

    // Make a runtime call to the new function, making sure to omit the comptime args.
    try sema.requireRuntimeBlock(block, call_src);

    const comptime_args = callee.comptime_args.?;
    const runtime_args_len = count: {
        var count: u32 = 0;
        var arg_i: usize = 0;
        for (fn_info.param_body) |inst| {
            switch (zir_tags[inst]) {
                .param_comptime, .param_anytype_comptime, .param, .param_anytype => {
                    if (comptime_args[arg_i].val.tag() == .generic_poison) {
                        count += 1;
                    }
                    arg_i += 1;
                },
                else => continue,
            }
        }
        break :count count;
    };
    const runtime_args = try sema.arena.alloc(Air.Inst.Ref, runtime_args_len);
    {
        const new_fn_ty = callee.owner_decl.ty;
        var runtime_i: u32 = 0;
        var total_i: u32 = 0;
        for (fn_info.param_body) |inst| {
            switch (zir_tags[inst]) {
                .param_comptime, .param_anytype_comptime, .param, .param_anytype => {},
                else => continue,
            }
            const is_runtime = comptime_args[total_i].val.tag() == .generic_poison;
            if (is_runtime) {
                const param_ty = new_fn_ty.fnParamType(runtime_i);
                const arg_src = call_src; // TODO: better source location
                const uncasted_arg = uncasted_args[total_i];
                try sema.resolveTypeLayout(block, arg_src, param_ty);
                const casted_arg = try sema.coerce(block, param_ty, uncasted_arg, arg_src);
                runtime_args[runtime_i] = casted_arg;
                runtime_i += 1;
            }
            total_i += 1;
        }

        try sema.resolveTypeLayout(block, call_src, new_fn_ty.fnReturnType());
    }
    try sema.air_extra.ensureUnusedCapacity(sema.gpa, @typeInfo(Air.Call).Struct.fields.len +
        runtime_args_len);
    const func_inst = try block.addInst(.{
        .tag = .call,
        .data = .{ .pl_op = .{
            .operand = callee_inst,
            .payload = sema.addExtraAssumeCapacity(Air.Call{
                .args_len = runtime_args_len,
            }),
        } },
    });
    sema.appendRefsAssumeCapacity(runtime_args);
    return func_inst;
}

fn zirIntType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const tracy = trace(@src());
    defer tracy.end();

    const int_type = sema.code.instructions.items(.data)[inst].int_type;
    const ty = try Module.makeIntType(sema.arena, int_type.signedness, int_type.bit_count);

    return sema.addType(ty);
}

fn zirOptionalType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const child_type = try sema.resolveType(block, src, inst_data.operand);
    const opt_type = try Type.optional(sema.arena, child_type);

    return sema.addType(opt_type);
}

fn zirElemType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const array_type = try sema.resolveType(block, src, inst_data.operand);
    const elem_type = array_type.elemType();
    return sema.addType(elem_type);
}

fn zirVectorType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const elem_type_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const len_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const len = try sema.resolveAlreadyCoercedInt(block, len_src, extra.lhs, u32);
    const elem_type = try sema.resolveType(block, elem_type_src, extra.rhs);
    const vector_type = try Type.Tag.vector.create(sema.arena, .{
        .len = len,
        .elem_type = elem_type,
    });
    return sema.addType(vector_type);
}

fn zirArrayType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const len = try sema.resolveInt(block, .unneeded, bin_inst.lhs, Type.usize);
    const elem_type = try sema.resolveType(block, .unneeded, bin_inst.rhs);
    const array_ty = try Type.array(sema.arena, len, null, elem_type);

    return sema.addType(array_ty);
}

fn zirArrayTypeSentinel(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.ArrayTypeSentinel, inst_data.payload_index).data;
    const len_src: LazySrcLoc = .{ .node_offset_array_type_len = inst_data.src_node };
    const sentinel_src: LazySrcLoc = .{ .node_offset_array_type_sentinel = inst_data.src_node };
    const elem_src: LazySrcLoc = .{ .node_offset_array_type_elem = inst_data.src_node };
    const len = try sema.resolveInt(block, len_src, extra.len, Type.usize);
    const elem_type = try sema.resolveType(block, elem_src, extra.elem_type);
    const uncasted_sentinel = sema.resolveInst(extra.sentinel);
    const sentinel = try sema.coerce(block, elem_type, uncasted_sentinel, sentinel_src);
    const sentinel_val = try sema.resolveConstValue(block, sentinel_src, sentinel);
    const array_ty = try Type.array(sema.arena, len, sentinel_val, elem_type);

    return sema.addType(array_ty);
}

fn zirAnyframeType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_anyframe_type = inst_data.src_node };
    const return_type = try sema.resolveType(block, operand_src, inst_data.operand);
    const anyframe_type = try Type.Tag.anyframe_T.create(sema.arena, return_type);

    return sema.addType(anyframe_type);
}

fn zirErrorUnionType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const error_union = try sema.resolveType(block, lhs_src, extra.lhs);
    const payload = try sema.resolveType(block, rhs_src, extra.rhs);

    if (error_union.zigTypeTag() != .ErrorSet) {
        return sema.fail(block, lhs_src, "expected error set type, found {}", .{
            error_union.elemType(),
        });
    }
    const err_union_ty = try Module.errorUnionType(sema.arena, error_union, payload);
    return sema.addType(err_union_ty);
}

fn zirErrorValue(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;

    // Create an anonymous error set type with only this error value, and return the value.
    const kv = try sema.mod.getErrorValue(inst_data.get(sema.code));
    const result_type = try Type.Tag.error_set_single.create(sema.arena, kv.key);
    return sema.addConstant(
        result_type,
        try Value.Tag.@"error".create(sema.arena, .{
            .name = kv.key,
        }),
    );
}

fn zirErrorToInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const op = sema.resolveInst(inst_data.operand);
    const op_coerced = try sema.coerce(block, Type.anyerror, op, operand_src);
    const result_ty = Type.initTag(.u16);

    if (try sema.resolveMaybeUndefVal(block, src, op_coerced)) |val| {
        if (val.isUndef()) {
            return sema.addConstUndef(result_ty);
        }
        const payload = try sema.arena.create(Value.Payload.U64);
        payload.* = .{
            .base = .{ .tag = .int_u64 },
            .data = (try sema.mod.getErrorValue(val.castTag(.@"error").?.data.name)).value,
        };
        return sema.addConstant(result_ty, Value.initPayload(&payload.base));
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addBitCast(result_ty, op_coerced);
}

fn zirIntToError(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };

    const op = sema.resolveInst(inst_data.operand);

    if (try sema.resolveDefinedValue(block, operand_src, op)) |value| {
        const int = value.toUnsignedInt();
        if (int > sema.mod.global_error_set.count() or int == 0)
            return sema.fail(block, operand_src, "integer value {d} represents no error", .{int});
        const payload = try sema.arena.create(Value.Payload.Error);
        payload.* = .{
            .base = .{ .tag = .@"error" },
            .data = .{ .name = sema.mod.error_name_list.items[@intCast(usize, int)] },
        };
        return sema.addConstant(Type.anyerror, Value.initPayload(&payload.base));
    }
    try sema.requireRuntimeBlock(block, src);
    if (block.wantSafety()) {
        return sema.fail(block, src, "TODO: get max errors in compilation", .{});
        // const is_gt_max = @panic("TODO get max errors in compilation");
        // try sema.addSafetyCheck(block, is_gt_max, .invalid_error_code);
    }
    return block.addInst(.{
        .tag = .bitcast,
        .data = .{ .ty_op = .{
            .ty = Air.Inst.Ref.anyerror_type,
            .operand = op,
        } },
    });
}

fn zirMergeErrorSets(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    if (sema.typeOf(lhs).zigTypeTag() == .Bool and sema.typeOf(rhs).zigTypeTag() == .Bool) {
        const msg = msg: {
            const msg = try sema.errMsg(block, lhs_src, "expected error set type, found 'bool'", .{});
            errdefer msg.destroy(sema.gpa);
            try sema.errNote(block, src, msg, "'||' merges error sets; 'or' performs boolean OR", .{});
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }
    const lhs_ty = try sema.analyzeAsType(block, lhs_src, lhs);
    const rhs_ty = try sema.analyzeAsType(block, rhs_src, rhs);
    if (lhs_ty.zigTypeTag() != .ErrorSet)
        return sema.fail(block, lhs_src, "expected error set type, found {}", .{lhs_ty});
    if (rhs_ty.zigTypeTag() != .ErrorSet)
        return sema.fail(block, rhs_src, "expected error set type, found {}", .{rhs_ty});

    // Anything merged with anyerror is anyerror.
    if (lhs_ty.tag() == .anyerror or rhs_ty.tag() == .anyerror) {
        return Air.Inst.Ref.anyerror_type;
    }
    // When we support inferred error sets, we'll want to use a data structure that can
    // represent a merged set of errors without forcing them to be resolved here. Until then
    // we re-use the same data structure that is used for explicit error set declarations.
    var set: std.StringHashMapUnmanaged(void) = .{};
    defer set.deinit(sema.gpa);

    switch (lhs_ty.tag()) {
        .error_set_single => {
            const name = lhs_ty.castTag(.error_set_single).?.data;
            try set.put(sema.gpa, name, {});
        },
        .error_set => {
            const lhs_set = lhs_ty.castTag(.error_set).?.data;
            try set.ensureUnusedCapacity(sema.gpa, lhs_set.names_len);
            for (lhs_set.names_ptr[0..lhs_set.names_len]) |name| {
                set.putAssumeCapacityNoClobber(name, {});
            }
        },
        else => unreachable,
    }
    switch (rhs_ty.tag()) {
        .error_set_single => {
            const name = rhs_ty.castTag(.error_set_single).?.data;
            try set.put(sema.gpa, name, {});
        },
        .error_set => {
            const rhs_set = rhs_ty.castTag(.error_set).?.data;
            try set.ensureUnusedCapacity(sema.gpa, rhs_set.names_len);
            for (rhs_set.names_ptr[0..rhs_set.names_len]) |name| {
                set.putAssumeCapacity(name, {});
            }
        },
        else => unreachable,
    }

    const new_names = try sema.arena.alloc([]const u8, set.count());
    var it = set.keyIterator();
    var i: usize = 0;
    while (it.next()) |key| : (i += 1) {
        new_names[i] = key.*;
    }

    const new_error_set = try sema.arena.create(Module.ErrorSet);
    new_error_set.* = .{
        .owner_decl = sema.owner_decl,
        .node_offset = inst_data.src_node,
        .names_ptr = new_names.ptr,
        .names_len = @intCast(u32, new_names.len),
    };
    const error_set_ty = try Type.Tag.error_set.create(sema.arena, new_error_set);
    return sema.addConstant(Type.type, try Value.Tag.ty.create(sema.arena, error_set_ty));
}

fn zirEnumLiteral(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const duped_name = try sema.arena.dupe(u8, inst_data.get(sema.code));
    return sema.addConstant(
        Type.initTag(.enum_literal),
        try Value.Tag.enum_literal.create(sema.arena, duped_name),
    );
}

fn zirEnumToInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);

    const enum_tag: Air.Inst.Ref = switch (operand_ty.zigTypeTag()) {
        .Enum => operand,
        .Union => {
            //if (!operand_ty.unionHasTag()) {
            //    return sema.fail(
            //        block,
            //        operand_src,
            //        "untagged union '{}' cannot be converted to integer",
            //        .{dest_ty_src},
            //    );
            //}
            return sema.fail(block, operand_src, "TODO zirEnumToInt for tagged unions", .{});
        },
        else => {
            return sema.fail(block, operand_src, "expected enum or tagged union, found {}", .{
                operand_ty,
            });
        },
    };
    const enum_tag_ty = sema.typeOf(enum_tag);

    var int_tag_type_buffer: Type.Payload.Bits = undefined;
    const int_tag_ty = try enum_tag_ty.intTagType(&int_tag_type_buffer).copy(arena);

    if (try sema.typeHasOnePossibleValue(block, src, enum_tag_ty)) |opv| {
        return sema.addConstant(int_tag_ty, opv);
    }

    if (try sema.resolveMaybeUndefVal(block, operand_src, enum_tag)) |enum_tag_val| {
        var buffer: Value.Payload.U64 = undefined;
        const val = enum_tag_val.enumToInt(enum_tag_ty, &buffer);
        return sema.addConstant(int_tag_ty, try val.copy(sema.arena));
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addBitCast(int_tag_ty, enum_tag);
}

fn zirIntToEnum(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const target = sema.mod.getTarget();
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);

    if (dest_ty.zigTypeTag() != .Enum) {
        return sema.fail(block, dest_ty_src, "expected enum, found {}", .{dest_ty});
    }

    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |int_val| {
        if (dest_ty.isNonexhaustiveEnum()) {
            return sema.addConstant(dest_ty, int_val);
        }
        if (int_val.isUndef()) {
            return sema.failWithUseOfUndef(block, operand_src);
        }
        if (!dest_ty.enumHasInt(int_val, target)) {
            const msg = msg: {
                const msg = try sema.errMsg(
                    block,
                    src,
                    "enum '{}' has no tag with value {}",
                    .{ dest_ty, int_val },
                );
                errdefer msg.destroy(sema.gpa);
                try sema.mod.errNoteNonLazy(
                    dest_ty.declSrcLoc(),
                    msg,
                    "enum declared here",
                    .{},
                );
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        return sema.addConstant(dest_ty, int_val);
    }

    try sema.requireRuntimeBlock(block, src);
    // TODO insert safety check to make sure the value matches an enum value
    return block.addTyOp(.intcast, dest_ty, operand);
}

/// Pointer in, pointer out.
fn zirOptionalPayloadPtr(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    safety_check: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const optional_ptr = sema.resolveInst(inst_data.operand);
    const optional_ptr_ty = sema.typeOf(optional_ptr);
    assert(optional_ptr_ty.zigTypeTag() == .Pointer);
    const src = inst_data.src();

    const opt_type = optional_ptr_ty.elemType();
    if (opt_type.zigTypeTag() != .Optional) {
        return sema.fail(block, src, "expected optional type, found {}", .{opt_type});
    }

    const child_type = try opt_type.optionalChildAlloc(sema.arena);
    const child_pointer = try Type.ptr(sema.arena, .{
        .pointee_type = child_type,
        .mutable = !optional_ptr_ty.isConstPtr(),
        .@"addrspace" = optional_ptr_ty.ptrAddressSpace(),
    });

    if (try sema.resolveDefinedValue(block, src, optional_ptr)) |pointer_val| {
        if (try sema.pointerDeref(block, src, pointer_val, optional_ptr_ty)) |val| {
            if (val.isNull()) {
                return sema.fail(block, src, "unable to unwrap null", .{});
            }
            // The same Value represents the pointer to the optional and the payload.
            return sema.addConstant(
                child_pointer,
                try Value.Tag.opt_payload_ptr.create(sema.arena, pointer_val),
            );
        }
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_null = try block.addUnOp(.is_non_null_ptr, optional_ptr);
        try sema.addSafetyCheck(block, is_non_null, .unwrap_null);
    }
    return block.addTyOp(.optional_payload_ptr, child_pointer, optional_ptr);
}

/// Value in, value out.
fn zirOptionalPayload(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    safety_check: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    const result_ty = switch (operand_ty.zigTypeTag()) {
        .Optional => try operand_ty.optionalChildAlloc(sema.arena),
        .Pointer => t: {
            if (operand_ty.ptrSize() != .C) {
                return sema.failWithExpectedOptionalType(block, src, operand_ty);
            }
            const ptr_info = operand_ty.ptrInfo().data;
            break :t try Type.ptr(sema.arena, .{
                .pointee_type = try ptr_info.pointee_type.copy(sema.arena),
                .@"align" = ptr_info.@"align",
                .@"addrspace" = ptr_info.@"addrspace",
                .mutable = ptr_info.mutable,
                .@"allowzero" = ptr_info.@"allowzero",
                .@"volatile" = ptr_info.@"volatile",
                .size = .One,
            });
        },
        else => return sema.failWithExpectedOptionalType(block, src, operand_ty),
    };

    if (try sema.resolveDefinedValue(block, src, operand)) |val| {
        if (val.isNull()) {
            return sema.fail(block, src, "unable to unwrap null", .{});
        }
        const sub_val = val.castTag(.opt_payload).?.data;
        return sema.addConstant(result_ty, sub_val);
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_null = try block.addUnOp(.is_non_null, operand);
        try sema.addSafetyCheck(block, is_non_null, .unwrap_null);
    }
    return block.addTyOp(.optional_payload, result_ty, operand);
}

/// Value in, value out
fn zirErrUnionPayload(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    safety_check: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_src = src;
    const operand_ty = sema.typeOf(operand);
    if (operand_ty.zigTypeTag() != .ErrorUnion)
        return sema.fail(block, operand_src, "expected error union type, found '{}'", .{operand_ty});

    if (try sema.resolveDefinedValue(block, src, operand)) |val| {
        if (val.getError()) |name| {
            return sema.fail(block, src, "caught unexpected error '{s}'", .{name});
        }
        const data = val.castTag(.eu_payload).?.data;
        const result_ty = operand_ty.errorUnionPayload();
        return sema.addConstant(result_ty, data);
    }
    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_err = try block.addUnOp(.is_err, operand);
        try sema.addSafetyCheck(block, is_non_err, .unwrap_errunion);
    }
    const result_ty = operand_ty.errorUnionPayload();
    return block.addTyOp(.unwrap_errunion_payload, result_ty, operand);
}

/// Pointer in, pointer out.
fn zirErrUnionPayloadPtr(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    safety_check: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    assert(operand_ty.zigTypeTag() == .Pointer);

    if (operand_ty.elemType().zigTypeTag() != .ErrorUnion)
        return sema.fail(block, src, "expected error union type, found {}", .{operand_ty.elemType()});

    const payload_ty = operand_ty.elemType().errorUnionPayload();
    const operand_pointer_ty = try Type.ptr(sema.arena, .{
        .pointee_type = payload_ty,
        .mutable = !operand_ty.isConstPtr(),
        .@"addrspace" = operand_ty.ptrAddressSpace(),
    });

    if (try sema.resolveDefinedValue(block, src, operand)) |pointer_val| {
        if (try sema.pointerDeref(block, src, pointer_val, operand_ty)) |val| {
            if (val.getError()) |name| {
                return sema.fail(block, src, "caught unexpected error '{s}'", .{name});
            }
            return sema.addConstant(
                operand_pointer_ty,
                try Value.Tag.eu_payload_ptr.create(sema.arena, pointer_val),
            );
        }
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_err = try block.addUnOp(.is_err, operand);
        try sema.addSafetyCheck(block, is_non_err, .unwrap_errunion);
    }
    return block.addTyOp(.unwrap_errunion_payload_ptr, operand_pointer_ty, operand);
}

/// Value in, value out
fn zirErrUnionCode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    if (operand_ty.zigTypeTag() != .ErrorUnion)
        return sema.fail(block, src, "expected error union type, found '{}'", .{operand_ty});

    const result_ty = operand_ty.errorUnionSet();

    if (try sema.resolveDefinedValue(block, src, operand)) |val| {
        assert(val.getError() != null);
        return sema.addConstant(result_ty, val);
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.unwrap_errunion_err, result_ty, operand);
}

/// Pointer in, value out
fn zirErrUnionCodePtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    assert(operand_ty.zigTypeTag() == .Pointer);

    if (operand_ty.elemType().zigTypeTag() != .ErrorUnion)
        return sema.fail(block, src, "expected error union type, found {}", .{operand_ty.elemType()});

    const result_ty = operand_ty.elemType().errorUnionSet();

    if (try sema.resolveDefinedValue(block, src, operand)) |pointer_val| {
        if (try sema.pointerDeref(block, src, pointer_val, operand_ty)) |val| {
            assert(val.getError() != null);
            return sema.addConstant(result_ty, val);
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.unwrap_errunion_err_ptr, result_ty, operand);
}

fn zirEnsureErrPayloadVoid(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    if (operand_ty.zigTypeTag() != .ErrorUnion)
        return sema.fail(block, src, "expected error union type, found '{}'", .{operand_ty});
    if (operand_ty.errorUnionPayload().zigTypeTag() != .Void) {
        return sema.fail(block, src, "expression value is ignored", .{});
    }
}

fn zirFunc(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    inferred_error_set: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Func, inst_data.payload_index);
    var extra_index = extra.end;
    const ret_ty_body = sema.code.extra[extra_index..][0..extra.data.ret_body_len];
    extra_index += ret_ty_body.len;

    var body_inst: Zir.Inst.Index = 0;
    var src_locs: Zir.Inst.Func.SrcLocs = undefined;
    if (extra.data.body_len != 0) {
        body_inst = inst;
        extra_index += extra.data.body_len;
        src_locs = sema.code.extraData(Zir.Inst.Func.SrcLocs, extra_index).data;
    }

    const cc: std.builtin.CallingConvention = if (sema.owner_decl.is_exported)
        .C
    else
        .Unspecified;

    return sema.funcCommon(
        block,
        inst_data.src_node,
        body_inst,
        ret_ty_body,
        cc,
        Value.@"null",
        false,
        inferred_error_set,
        false,
        src_locs,
        null,
    );
}

fn funcCommon(
    sema: *Sema,
    block: *Block,
    src_node_offset: i32,
    body_inst: Zir.Inst.Index,
    ret_ty_body: []const Zir.Inst.Index,
    cc: std.builtin.CallingConvention,
    align_val: Value,
    var_args: bool,
    inferred_error_set: bool,
    is_extern: bool,
    src_locs: Zir.Inst.Func.SrcLocs,
    opt_lib_name: ?[]const u8,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = src_node_offset };
    const ret_ty_src: LazySrcLoc = .{ .node_offset_fn_type_ret_ty = src_node_offset };

    // The return type body might be a type expression that depends on generic parameters.
    // In such case we need to use a generic_poison value for the return type and mark
    // the function as generic.
    var is_generic = false;
    const bare_return_type: Type = ret_ty: {
        if (ret_ty_body.len == 0) break :ret_ty Type.void;

        const err = err: {
            // Make sure any nested param instructions don't clobber our work.
            const prev_params = block.params;
            block.params = .{};
            defer {
                block.params.deinit(sema.gpa);
                block.params = prev_params;
            }
            if (sema.resolveBody(block, ret_ty_body)) |ret_ty_inst| {
                if (sema.analyzeAsType(block, ret_ty_src, ret_ty_inst)) |ret_ty| {
                    break :ret_ty ret_ty;
                } else |err| break :err err;
            } else |err| break :err err;
        };
        switch (err) {
            error.GenericPoison => {
                // The type is not available until the generic instantiation.
                is_generic = true;
                break :ret_ty Type.initTag(.generic_poison);
            },
            else => |e| return e,
        }
    };

    const mod = sema.mod;

    const new_func: *Module.Fn = new_func: {
        if (body_inst == 0) break :new_func undefined;
        if (sema.comptime_args_fn_inst == body_inst) {
            const new_func = sema.preallocated_new_func.?;
            sema.preallocated_new_func = null; // take ownership
            break :new_func new_func;
        }
        break :new_func try sema.gpa.create(Module.Fn);
    };
    errdefer if (body_inst != 0) sema.gpa.destroy(new_func);

    const fn_ty: Type = fn_ty: {
        // Hot path for some common function types.
        // TODO can we eliminate some of these Type tag values? seems unnecessarily complicated.
        if (!is_generic and block.params.items.len == 0 and !var_args and
            align_val.tag() == .null_value and !inferred_error_set)
        {
            if (bare_return_type.zigTypeTag() == .NoReturn and cc == .Unspecified) {
                break :fn_ty Type.initTag(.fn_noreturn_no_args);
            }

            if (bare_return_type.zigTypeTag() == .Void and cc == .Unspecified) {
                break :fn_ty Type.initTag(.fn_void_no_args);
            }

            if (bare_return_type.zigTypeTag() == .NoReturn and cc == .Naked) {
                break :fn_ty Type.initTag(.fn_naked_noreturn_no_args);
            }

            if (bare_return_type.zigTypeTag() == .Void and cc == .C) {
                break :fn_ty Type.initTag(.fn_ccc_void_no_args);
            }
        }

        const param_types = try sema.arena.alloc(Type, block.params.items.len);
        const comptime_params = try sema.arena.alloc(bool, block.params.items.len);
        for (block.params.items) |param, i| {
            param_types[i] = param.ty;
            comptime_params[i] = param.is_comptime;
            is_generic = is_generic or param.is_comptime or
                param.ty.tag() == .generic_poison or param.ty.requiresComptime();
        }

        if (align_val.tag() != .null_value) {
            return sema.fail(block, src, "TODO implement support for function prototypes to have alignment specified", .{});
        }

        is_generic = is_generic or bare_return_type.requiresComptime();

        const return_type = if (!inferred_error_set or bare_return_type.tag() == .generic_poison)
            bare_return_type
        else blk: {
            const error_set_ty = try Type.Tag.error_set_inferred.create(sema.arena, .{
                .func = new_func,
                .map = .{},
                .functions = .{},
                .is_anyerror = false,
            });
            break :blk try Type.Tag.error_union.create(sema.arena, .{
                .error_set = error_set_ty,
                .payload = bare_return_type,
            });
        };

        break :fn_ty try Type.Tag.function.create(sema.arena, .{
            .param_types = param_types,
            .comptime_params = comptime_params.ptr,
            .return_type = return_type,
            .cc = cc,
            .is_var_args = var_args,
            .is_generic = is_generic,
        });
    };

    if (opt_lib_name) |lib_name| blk: {
        const lib_name_src: LazySrcLoc = .{ .node_offset_lib_name = src_node_offset };
        log.debug("extern fn symbol expected in lib '{s}'", .{lib_name});
        mod.comp.stage1AddLinkLib(lib_name) catch |err| {
            return sema.fail(block, lib_name_src, "unable to add link lib '{s}': {s}", .{
                lib_name, @errorName(err),
            });
        };
        const target = mod.getTarget();
        if (target_util.is_libc_lib_name(target, lib_name)) {
            if (!mod.comp.bin_file.options.link_libc) {
                return sema.fail(
                    block,
                    lib_name_src,
                    "dependency on libc must be explicitly specified in the build command",
                    .{},
                );
            }
            break :blk;
        }
        if (target_util.is_libcpp_lib_name(target, lib_name)) {
            if (!mod.comp.bin_file.options.link_libcpp) {
                return sema.fail(
                    block,
                    lib_name_src,
                    "dependency on libc++ must be explicitly specified in the build command",
                    .{},
                );
            }
            break :blk;
        }
        if (!target.isWasm() and !mod.comp.bin_file.options.pic) {
            return sema.fail(
                block,
                lib_name_src,
                "dependency on dynamic library '{s}' requires enabling Position Independent Code. Fixed by `-l{s}` or `-fPIC`.",
                .{ lib_name, lib_name },
            );
        }
    }

    if (is_extern) {
        return sema.addConstant(
            fn_ty,
            try Value.Tag.extern_fn.create(sema.arena, sema.owner_decl),
        );
    }

    if (body_inst == 0) {
        const fn_ptr_ty = try Type.ptr(sema.arena, .{
            .pointee_type = fn_ty,
            .@"addrspace" = .generic,
            .mutable = false,
        });
        return sema.addType(fn_ptr_ty);
    }

    const is_inline = fn_ty.fnCallingConvention() == .Inline;
    const anal_state: Module.Fn.Analysis = if (is_inline) .inline_only else .queued;

    const comptime_args: ?[*]TypedValue = if (sema.comptime_args_fn_inst == body_inst) blk: {
        break :blk if (sema.comptime_args.len == 0) null else sema.comptime_args.ptr;
    } else null;

    const fn_payload = try sema.arena.create(Value.Payload.Function);
    new_func.* = .{
        .state = anal_state,
        .zir_body_inst = body_inst,
        .owner_decl = sema.owner_decl,
        .comptime_args = comptime_args,
        .lbrace_line = src_locs.lbrace_line,
        .rbrace_line = src_locs.rbrace_line,
        .lbrace_column = @truncate(u16, src_locs.columns),
        .rbrace_column = @truncate(u16, src_locs.columns >> 16),
    };
    fn_payload.* = .{
        .base = .{ .tag = .function },
        .data = new_func,
    };
    return sema.addConstant(fn_ty, Value.initPayload(&fn_payload.base));
}

fn zirParam(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_comptime: bool,
) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_tok;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.Param, inst_data.payload_index);
    const param_name = sema.code.nullTerminatedString(extra.data.name);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];

    // TODO check if param_name shadows a Decl. This only needs to be done if
    // usingnamespace is implemented.
    _ = param_name;

    // We could be in a generic function instantiation, or we could be evaluating a generic
    // function without any comptime args provided.
    const param_ty = param_ty: {
        const err = err: {
            // Make sure any nested param instructions don't clobber our work.
            const prev_params = block.params;
            block.params = .{};
            defer {
                block.params.deinit(sema.gpa);
                block.params = prev_params;
            }

            if (sema.resolveBody(block, body)) |param_ty_inst| {
                if (sema.analyzeAsType(block, src, param_ty_inst)) |param_ty| {
                    break :param_ty param_ty;
                } else |err| break :err err;
            } else |err| break :err err;
        };
        switch (err) {
            error.GenericPoison => {
                // The type is not available until the generic instantiation.
                // We result the param instruction with a poison value and
                // insert an anytype parameter.
                try block.params.append(sema.gpa, .{
                    .ty = Type.initTag(.generic_poison),
                    .is_comptime = is_comptime,
                });
                try sema.inst_map.putNoClobber(sema.gpa, inst, .generic_poison);
                return;
            },
            else => |e| return e,
        }
    };
    if (sema.inst_map.get(inst)) |arg| {
        if (is_comptime or param_ty.requiresComptime()) {
            // We have a comptime value for this parameter so it should be elided from the
            // function type of the function instruction in this block.
            const coerced_arg = try sema.coerce(block, param_ty, arg, src);
            sema.inst_map.putAssumeCapacity(inst, coerced_arg);
            return;
        }
        // Even though a comptime argument is provided, the generic function wants to treat
        // this as a runtime parameter.
        assert(sema.inst_map.remove(inst));
    }

    try block.params.append(sema.gpa, .{
        .ty = param_ty,
        .is_comptime = is_comptime or param_ty.requiresComptime(),
    });
    const result = try sema.addConstant(param_ty, Value.initTag(.generic_poison));
    try sema.inst_map.putNoClobber(sema.gpa, inst, result);
}

fn zirParamAnytype(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_comptime: bool,
) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const param_name = inst_data.get(sema.code);

    // TODO check if param_name shadows a Decl. This only needs to be done if
    // usingnamespace is implemented.
    _ = param_name;

    if (sema.inst_map.get(inst)) |air_ref| {
        const param_ty = sema.typeOf(air_ref);
        if (is_comptime or param_ty.requiresComptime()) {
            // We have a comptime value for this parameter so it should be elided from the
            // function type of the function instruction in this block.
            return;
        }
        // The map is already populated but we do need to add a runtime parameter.
        try block.params.append(sema.gpa, .{
            .ty = param_ty,
            .is_comptime = false,
        });
        return;
    }

    // We are evaluating a generic function without any comptime args provided.

    try block.params.append(sema.gpa, .{
        .ty = Type.initTag(.generic_poison),
        .is_comptime = is_comptime,
    });
    try sema.inst_map.put(sema.gpa, inst, .generic_poison);
}

fn zirAs(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    return sema.analyzeAs(block, .unneeded, bin_inst.lhs, bin_inst.rhs);
}

fn zirAsNode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.As, inst_data.payload_index).data;
    return sema.analyzeAs(block, src, extra.dest_type, extra.operand);
}

fn analyzeAs(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_dest_type: Zir.Inst.Ref,
    zir_operand: Zir.Inst.Ref,
) CompileError!Air.Inst.Ref {
    const dest_ty = try sema.resolveType(block, src, zir_dest_type);
    const operand = sema.resolveInst(zir_operand);
    return sema.coerce(block, dest_ty, operand, src);
}

fn zirPtrToInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ptr = sema.resolveInst(inst_data.operand);
    const ptr_ty = sema.typeOf(ptr);
    if (ptr_ty.zigTypeTag() != .Pointer) {
        const ptr_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
        return sema.fail(block, ptr_src, "expected pointer, found '{}'", .{ptr_ty});
    }
    // TODO handle known-pointer-address
    const src = inst_data.src();
    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(.ptrtoint, ptr);
}

fn zirFieldVal(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_field_name = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Field, inst_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(extra.field_name_start);
    const object = sema.resolveInst(extra.lhs);
    return sema.fieldVal(block, src, object, field_name, field_name_src);
}

fn zirFieldPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_field_name = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Field, inst_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(extra.field_name_start);
    const object_ptr = sema.resolveInst(extra.lhs);
    return sema.fieldPtr(block, src, object_ptr, field_name, field_name_src);
}

fn zirFieldCallBind(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_field_name = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Field, inst_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(extra.field_name_start);
    const object_ptr = sema.resolveInst(extra.lhs);
    return sema.fieldCallBind(block, src, object_ptr, field_name, field_name_src);
}

fn zirFieldValNamed(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.FieldNamed, inst_data.payload_index).data;
    const object = sema.resolveInst(extra.lhs);
    const field_name = try sema.resolveConstString(block, field_name_src, extra.field_name);
    return sema.fieldVal(block, src, object, field_name, field_name_src);
}

fn zirFieldPtrNamed(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.FieldNamed, inst_data.payload_index).data;
    const object_ptr = sema.resolveInst(extra.lhs);
    const field_name = try sema.resolveConstString(block, field_name_src, extra.field_name);
    return sema.fieldPtr(block, src, object_ptr, field_name, field_name_src);
}

fn zirFieldCallBindNamed(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.FieldNamed, inst_data.payload_index).data;
    const object_ptr = sema.resolveInst(extra.lhs);
    const field_name = try sema.resolveConstString(block, field_name_src, extra.field_name);
    return sema.fieldCallBind(block, src, object_ptr, field_name, field_name_src);
}

fn zirIntCast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;

    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);

    const dest_is_comptime_int = try sema.checkIntType(block, dest_ty_src, dest_ty);
    _ = try sema.checkIntType(block, operand_src, sema.typeOf(operand));

    if (try sema.isComptimeKnown(block, operand_src, operand)) {
        return sema.coerce(block, dest_ty, operand, operand_src);
    } else if (dest_is_comptime_int) {
        return sema.fail(block, src, "unable to cast runtime value to 'comptime_int'", .{});
    }

    try sema.requireRuntimeBlock(block, operand_src);
    // TODO insert safety check to make sure the value fits in the dest type
    return block.addTyOp(.intcast, dest_ty, operand);
}

fn zirBitcast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;

    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);
    return sema.bitCast(block, dest_ty, operand, operand_src);
}

fn zirFloatCast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;

    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);

    const dest_is_comptime_float = switch (dest_ty.zigTypeTag()) {
        .ComptimeFloat => true,
        .Float => false,
        else => return sema.fail(
            block,
            dest_ty_src,
            "expected float type, found '{}'",
            .{dest_ty},
        ),
    };

    const operand_ty = sema.typeOf(operand);
    switch (operand_ty.zigTypeTag()) {
        .ComptimeFloat, .Float, .ComptimeInt => {},
        else => return sema.fail(
            block,
            operand_src,
            "expected float type, found '{}'",
            .{operand_ty},
        ),
    }

    if (try sema.isComptimeKnown(block, operand_src, operand)) {
        return sema.coerce(block, dest_ty, operand, operand_src);
    }
    if (dest_is_comptime_float) {
        return sema.fail(block, src, "unable to cast runtime value to 'comptime_float'", .{});
    }
    const target = sema.mod.getTarget();
    const src_bits = operand_ty.floatBits(target);
    const dst_bits = dest_ty.floatBits(target);
    if (dst_bits >= src_bits) {
        return sema.coerce(block, dest_ty, operand, operand_src);
    }
    try sema.requireRuntimeBlock(block, operand_src);
    return block.addTyOp(.fptrunc, dest_ty, operand);
}

fn zirElemVal(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const array = sema.resolveInst(bin_inst.lhs);
    const elem_index = sema.resolveInst(bin_inst.rhs);
    return sema.elemVal(block, sema.src, array, elem_index, sema.src);
}

fn zirElemValNode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const elem_index_src: LazySrcLoc = .{ .node_offset_array_access_index = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const array = sema.resolveInst(extra.lhs);
    const elem_index = sema.resolveInst(extra.rhs);
    return sema.elemVal(block, src, array, elem_index, elem_index_src);
}

fn zirElemPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const array_ptr = sema.resolveInst(bin_inst.lhs);
    const elem_index = sema.resolveInst(bin_inst.rhs);
    return sema.elemPtr(block, sema.src, array_ptr, elem_index, sema.src);
}

fn zirElemPtrNode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const elem_index_src: LazySrcLoc = .{ .node_offset_array_access_index = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const array_ptr = sema.resolveInst(extra.lhs);
    const elem_index = sema.resolveInst(extra.rhs);
    return sema.elemPtr(block, src, array_ptr, elem_index, elem_index_src);
}

fn zirElemPtrImm(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.ElemPtrImm, inst_data.payload_index).data;
    const array_ptr = sema.resolveInst(extra.ptr);
    const elem_index = try sema.addIntUnsigned(Type.usize, extra.index);
    return sema.elemPtr(block, src, array_ptr, elem_index, src);
}

fn zirSliceStart(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.SliceStart, inst_data.payload_index).data;
    const array_ptr = sema.resolveInst(extra.lhs);
    const start = sema.resolveInst(extra.start);

    return sema.analyzeSlice(block, src, array_ptr, start, .none, .none, .unneeded);
}

fn zirSliceEnd(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(Zir.Inst.SliceEnd, inst_data.payload_index).data;
    const array_ptr = sema.resolveInst(extra.lhs);
    const start = sema.resolveInst(extra.start);
    const end = sema.resolveInst(extra.end);

    return sema.analyzeSlice(block, src, array_ptr, start, end, .none, .unneeded);
}

fn zirSliceSentinel(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const sentinel_src: LazySrcLoc = .{ .node_offset_slice_sentinel = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.SliceSentinel, inst_data.payload_index).data;
    const array_ptr = sema.resolveInst(extra.lhs);
    const start = sema.resolveInst(extra.start);
    const end = sema.resolveInst(extra.end);
    const sentinel = sema.resolveInst(extra.sentinel);

    return sema.analyzeSlice(block, src, array_ptr, start, end, sentinel, sentinel_src);
}

fn zirSwitchCapture(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_multi: bool,
    is_ref: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_datas = sema.code.instructions.items(.data);
    const capture_info = zir_datas[inst].switch_capture;
    const switch_info = zir_datas[capture_info.switch_inst].pl_node;
    const switch_extra = sema.code.extraData(Zir.Inst.SwitchBlock, switch_info.payload_index);
    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = switch_info.src_node };
    const switch_src = switch_info.src();
    const operand_is_ref = switch_extra.data.bits.is_ref;
    const cond_inst = Zir.refToIndex(switch_extra.data.operand).?;
    const cond_info = sema.code.instructions.items(.data)[cond_inst].un_node;
    const operand_ptr = sema.resolveInst(cond_info.operand);
    const operand_ptr_ty = sema.typeOf(operand_ptr);
    const operand_ty = if (operand_is_ref) operand_ptr_ty.childType() else operand_ptr_ty;

    if (is_multi) {
        return sema.fail(block, switch_src, "TODO implement Sema for switch capture multi", .{});
    }
    const scalar_prong = switch_extra.data.getScalarProng(sema.code, switch_extra.end, capture_info.prong_index);
    const item = sema.resolveInst(scalar_prong.item);
    // Previous switch validation ensured this will succeed
    const item_val = sema.resolveConstValue(block, .unneeded, item) catch unreachable;

    switch (operand_ty.zigTypeTag()) {
        .Union => {
            const union_obj = operand_ty.cast(Type.Payload.Union).?.data;
            const enum_ty = union_obj.tag_ty;

            const field_index_usize = enum_ty.enumTagFieldIndex(item_val).?;
            const field_index = @intCast(u32, field_index_usize);
            const field = union_obj.fields.values()[field_index];

            // TODO handle multiple union tags which have compatible types

            if (is_ref) {
                assert(operand_is_ref);

                const field_ty_ptr = try Type.ptr(sema.arena, .{
                    .pointee_type = field.ty,
                    .@"addrspace" = .generic,
                    .mutable = operand_ptr_ty.ptrIsMutable(),
                });

                if (try sema.resolveDefinedValue(block, operand_src, operand_ptr)) |op_ptr_val| {
                    return sema.addConstant(
                        field_ty_ptr,
                        try Value.Tag.field_ptr.create(sema.arena, .{
                            .container_ptr = op_ptr_val,
                            .field_index = field_index,
                        }),
                    );
                }
                try sema.requireRuntimeBlock(block, operand_src);
                return block.addStructFieldPtr(operand_ptr, field_index, field_ty_ptr);
            }

            const operand = if (operand_is_ref)
                try sema.analyzeLoad(block, operand_src, operand_ptr, operand_src)
            else
                operand_ptr;

            if (try sema.resolveDefinedValue(block, operand_src, operand)) |operand_val| {
                return sema.addConstant(
                    field.ty,
                    operand_val.castTag(.@"union").?.data.val,
                );
            }
            try sema.requireRuntimeBlock(block, operand_src);
            return block.addStructFieldVal(operand, field_index, field.ty);
        },
        .ErrorSet => {
            return sema.fail(block, operand_src, "TODO implement Sema for zirSwitchCapture for error sets", .{});
        },
        else => {
            return sema.fail(block, operand_src, "switch on type '{}' provides no capture value", .{
                operand_ty,
            });
        },
    }
}

fn zirSwitchCaptureElse(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_ref: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_datas = sema.code.instructions.items(.data);
    const capture_info = zir_datas[inst].switch_capture;
    const switch_info = zir_datas[capture_info.switch_inst].pl_node;
    const switch_extra = sema.code.extraData(Zir.Inst.SwitchBlock, switch_info.payload_index).data;
    const src = switch_info.src();
    const operand_is_ref = switch_extra.bits.is_ref;
    assert(!is_ref or operand_is_ref);

    return sema.fail(block, src, "TODO implement Sema for zirSwitchCaptureElse", .{});
}

fn zirSwitchCond(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_ref: bool,
) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_ptr = sema.resolveInst(inst_data.operand);
    const operand = if (is_ref) try sema.analyzeLoad(block, src, operand_ptr, src) else operand_ptr;
    const operand_ty = sema.typeOf(operand);

    switch (operand_ty.zigTypeTag()) {
        .Type,
        .Void,
        .Bool,
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        .EnumLiteral,
        .Pointer,
        .Fn,
        .ErrorSet,
        .Enum,
        => {
            if ((try sema.typeHasOnePossibleValue(block, src, operand_ty))) |opv| {
                return sema.addConstant(operand_ty, opv);
            }
            return operand;
        },

        .Union => {
            const enum_ty = operand_ty.unionTagType() orelse {
                const msg = msg: {
                    const msg = try sema.errMsg(block, src, "switch on untagged union", .{});
                    errdefer msg.destroy(sema.gpa);
                    try sema.addDeclaredHereNote(msg, operand_ty);
                    break :msg msg;
                };
                return sema.failWithOwnedErrorMsg(msg);
            };
            return sema.unionToTag(block, enum_ty, operand, src);
        },

        .ErrorUnion,
        .NoReturn,
        .Array,
        .Struct,
        .Undefined,
        .Null,
        .Optional,
        .BoundFn,
        .Opaque,
        .Vector,
        .Frame,
        .AnyFrame,
        => return sema.fail(block, src, "switch on type '{}'", .{operand_ty}),
    }
}

fn zirSwitchBlock(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = sema.gpa;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const src_node_offset = inst_data.src_node;
    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = src_node_offset };
    const special_prong_src: LazySrcLoc = .{ .node_offset_switch_special_prong = src_node_offset };
    const extra = sema.code.extraData(Zir.Inst.SwitchBlock, inst_data.payload_index);

    const operand = sema.resolveInst(extra.data.operand);

    var header_extra_index: usize = extra.end;

    const scalar_cases_len = extra.data.bits.scalar_cases_len;
    const multi_cases_len = if (extra.data.bits.has_multi_cases) blk: {
        const multi_cases_len = sema.code.extra[header_extra_index];
        header_extra_index += 1;
        break :blk multi_cases_len;
    } else 0;

    const special_prong = extra.data.bits.specialProng();
    const special: struct { body: []const Zir.Inst.Index, end: usize } = switch (special_prong) {
        .none => .{ .body = &.{}, .end = header_extra_index },
        .under, .@"else" => blk: {
            const body_len = sema.code.extra[header_extra_index];
            const extra_body_start = header_extra_index + 1;
            break :blk .{
                .body = sema.code.extra[extra_body_start..][0..body_len],
                .end = extra_body_start + body_len,
            };
        },
    };

    const operand_ty = sema.typeOf(operand);

    // Validate usage of '_' prongs.
    if (special_prong == .under and !operand_ty.isNonexhaustiveEnum()) {
        const msg = msg: {
            const msg = try sema.errMsg(
                block,
                src,
                "'_' prong only allowed when switching on non-exhaustive enums",
                .{},
            );
            errdefer msg.destroy(gpa);
            try sema.errNote(
                block,
                special_prong_src,
                msg,
                "'_' prong here",
                .{},
            );
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }

    // Validate for duplicate items, missing else prong, and invalid range.
    switch (operand_ty.zigTypeTag()) {
        .Enum => {
            var seen_fields = try gpa.alloc(?Module.SwitchProngSrc, operand_ty.enumFieldCount());
            defer gpa.free(seen_fields);

            mem.set(?Module.SwitchProngSrc, seen_fields, null);

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    extra_index += body_len;

                    try sema.validateSwitchItemEnum(
                        block,
                        seen_fields,
                        item_ref,
                        src_node_offset,
                        .{ .scalar = scalar_i },
                    );
                }
            }
            {
                var multi_i: u32 = 0;
                while (multi_i < multi_cases_len) : (multi_i += 1) {
                    const items_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const ranges_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const items = sema.code.refSlice(extra_index, items_len);
                    extra_index += items_len + body_len;

                    for (items) |item_ref, item_i| {
                        try sema.validateSwitchItemEnum(
                            block,
                            seen_fields,
                            item_ref,
                            src_node_offset,
                            .{ .multi = .{ .prong = multi_i, .item = @intCast(u32, item_i) } },
                        );
                    }

                    try sema.validateSwitchNoRange(block, ranges_len, operand_ty, src_node_offset);
                }
            }
            const all_tags_handled = for (seen_fields) |seen_src| {
                if (seen_src == null) break false;
            } else true;

            switch (special_prong) {
                .none => {
                    if (!all_tags_handled) {
                        const msg = msg: {
                            const msg = try sema.errMsg(
                                block,
                                src,
                                "switch must handle all possibilities",
                                .{},
                            );
                            errdefer msg.destroy(sema.gpa);
                            for (seen_fields) |seen_src, i| {
                                if (seen_src != null) continue;

                                const field_name = operand_ty.enumFieldName(i);

                                // TODO have this point to the tag decl instead of here
                                try sema.errNote(
                                    block,
                                    src,
                                    msg,
                                    "unhandled enumeration value: '{s}'",
                                    .{field_name},
                                );
                            }
                            try sema.mod.errNoteNonLazy(
                                operand_ty.declSrcLoc(),
                                msg,
                                "enum '{}' declared here",
                                .{operand_ty},
                            );
                            break :msg msg;
                        };
                        return sema.failWithOwnedErrorMsg(msg);
                    }
                },
                .under => {
                    if (all_tags_handled) return sema.fail(
                        block,
                        special_prong_src,
                        "unreachable '_' prong; all cases already handled",
                        .{},
                    );
                },
                .@"else" => {
                    if (all_tags_handled) return sema.fail(
                        block,
                        special_prong_src,
                        "unreachable else prong; all cases already handled",
                        .{},
                    );
                },
            }
        },

        .ErrorSet => return sema.fail(block, src, "TODO validate switch .ErrorSet", .{}),
        .Union => return sema.fail(block, src, "TODO validate switch .Union", .{}),
        .Int, .ComptimeInt => {
            var range_set = RangeSet.init(gpa);
            defer range_set.deinit();

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    extra_index += body_len;

                    try sema.validateSwitchItem(
                        block,
                        &range_set,
                        item_ref,
                        operand_ty,
                        src_node_offset,
                        .{ .scalar = scalar_i },
                    );
                }
            }
            {
                var multi_i: u32 = 0;
                while (multi_i < multi_cases_len) : (multi_i += 1) {
                    const items_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const ranges_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const items = sema.code.refSlice(extra_index, items_len);
                    extra_index += items_len;

                    for (items) |item_ref, item_i| {
                        try sema.validateSwitchItem(
                            block,
                            &range_set,
                            item_ref,
                            operand_ty,
                            src_node_offset,
                            .{ .multi = .{ .prong = multi_i, .item = @intCast(u32, item_i) } },
                        );
                    }

                    var range_i: u32 = 0;
                    while (range_i < ranges_len) : (range_i += 1) {
                        const item_first = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                        extra_index += 1;
                        const item_last = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                        extra_index += 1;

                        try sema.validateSwitchRange(
                            block,
                            &range_set,
                            item_first,
                            item_last,
                            operand_ty,
                            src_node_offset,
                            .{ .range = .{ .prong = multi_i, .item = range_i } },
                        );
                    }

                    extra_index += body_len;
                }
            }

            check_range: {
                if (operand_ty.zigTypeTag() == .Int) {
                    var arena = std.heap.ArenaAllocator.init(gpa);
                    defer arena.deinit();

                    const target = sema.mod.getTarget();
                    const min_int = try operand_ty.minInt(&arena.allocator, target);
                    const max_int = try operand_ty.maxInt(&arena.allocator, target);
                    if (try range_set.spans(min_int, max_int, operand_ty)) {
                        if (special_prong == .@"else") {
                            return sema.fail(
                                block,
                                special_prong_src,
                                "unreachable else prong; all cases already handled",
                                .{},
                            );
                        }
                        break :check_range;
                    }
                }
                if (special_prong != .@"else") {
                    return sema.fail(
                        block,
                        src,
                        "switch must handle all possibilities",
                        .{},
                    );
                }
            }
        },
        .Bool => {
            var true_count: u8 = 0;
            var false_count: u8 = 0;

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    extra_index += body_len;

                    try sema.validateSwitchItemBool(
                        block,
                        &true_count,
                        &false_count,
                        item_ref,
                        src_node_offset,
                        .{ .scalar = scalar_i },
                    );
                }
            }
            {
                var multi_i: u32 = 0;
                while (multi_i < multi_cases_len) : (multi_i += 1) {
                    const items_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const ranges_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const items = sema.code.refSlice(extra_index, items_len);
                    extra_index += items_len + body_len;

                    for (items) |item_ref, item_i| {
                        try sema.validateSwitchItemBool(
                            block,
                            &true_count,
                            &false_count,
                            item_ref,
                            src_node_offset,
                            .{ .multi = .{ .prong = multi_i, .item = @intCast(u32, item_i) } },
                        );
                    }

                    try sema.validateSwitchNoRange(block, ranges_len, operand_ty, src_node_offset);
                }
            }
            switch (special_prong) {
                .@"else" => {
                    if (true_count + false_count == 2) {
                        return sema.fail(
                            block,
                            src,
                            "unreachable else prong; all cases already handled",
                            .{},
                        );
                    }
                },
                .under, .none => {
                    if (true_count + false_count < 2) {
                        return sema.fail(
                            block,
                            src,
                            "switch must handle all possibilities",
                            .{},
                        );
                    }
                },
            }
        },
        .EnumLiteral, .Void, .Fn, .Pointer, .Type => {
            if (special_prong != .@"else") {
                return sema.fail(
                    block,
                    src,
                    "else prong required when switching on type '{}'",
                    .{operand_ty},
                );
            }

            var seen_values = ValueSrcMap.initContext(gpa, .{ .ty = operand_ty });
            defer seen_values.deinit();

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    extra_index += body_len;

                    try sema.validateSwitchItemSparse(
                        block,
                        &seen_values,
                        item_ref,
                        src_node_offset,
                        .{ .scalar = scalar_i },
                    );
                }
            }
            {
                var multi_i: u32 = 0;
                while (multi_i < multi_cases_len) : (multi_i += 1) {
                    const items_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const ranges_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const items = sema.code.refSlice(extra_index, items_len);
                    extra_index += items_len + body_len;

                    for (items) |item_ref, item_i| {
                        try sema.validateSwitchItemSparse(
                            block,
                            &seen_values,
                            item_ref,
                            src_node_offset,
                            .{ .multi = .{ .prong = multi_i, .item = @intCast(u32, item_i) } },
                        );
                    }

                    try sema.validateSwitchNoRange(block, ranges_len, operand_ty, src_node_offset);
                }
            }
        },

        .ErrorUnion,
        .NoReturn,
        .Array,
        .Struct,
        .Undefined,
        .Null,
        .Optional,
        .BoundFn,
        .Opaque,
        .Vector,
        .Frame,
        .AnyFrame,
        .ComptimeFloat,
        .Float,
        => return sema.fail(block, operand_src, "invalid switch operand type '{}'", .{
            operand_ty,
        }),
    }

    const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
    try sema.air_instructions.append(gpa, .{
        .tag = .block,
        .data = undefined,
    });
    var label: Block.Label = .{
        .zir_block = inst,
        .merges = .{
            .results = .{},
            .br_list = .{},
            .block_inst = block_inst,
        },
    };

    var child_block: Block = .{
        .parent = block,
        .sema = sema,
        .src_decl = block.src_decl,
        .namespace = block.namespace,
        .wip_capture_scope = block.wip_capture_scope,
        .instructions = .{},
        .label = &label,
        .inlining = block.inlining,
        .is_comptime = block.is_comptime,
    };
    const merges = &child_block.label.?.merges;
    defer child_block.instructions.deinit(gpa);
    defer merges.results.deinit(gpa);
    defer merges.br_list.deinit(gpa);

    if (try sema.resolveDefinedValue(&child_block, src, operand)) |operand_val| {
        var extra_index: usize = special.end;
        {
            var scalar_i: usize = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                extra_index += 1;
                const body_len = sema.code.extra[extra_index];
                extra_index += 1;
                const body = sema.code.extra[extra_index..][0..body_len];
                extra_index += body_len;

                const item = sema.resolveInst(item_ref);
                // Validation above ensured these will succeed.
                const item_val = sema.resolveConstValue(&child_block, .unneeded, item) catch unreachable;
                if (operand_val.eql(item_val, operand_ty)) {
                    return sema.resolveBlockBody(block, src, &child_block, body, merges);
                }
            }
        }
        {
            var multi_i: usize = 0;
            while (multi_i < multi_cases_len) : (multi_i += 1) {
                const items_len = sema.code.extra[extra_index];
                extra_index += 1;
                const ranges_len = sema.code.extra[extra_index];
                extra_index += 1;
                const body_len = sema.code.extra[extra_index];
                extra_index += 1;
                const items = sema.code.refSlice(extra_index, items_len);
                extra_index += items_len;
                const body = sema.code.extra[extra_index + 2 * ranges_len ..][0..body_len];

                for (items) |item_ref| {
                    const item = sema.resolveInst(item_ref);
                    // Validation above ensured these will succeed.
                    const item_val = sema.resolveConstValue(&child_block, .unneeded, item) catch unreachable;
                    if (operand_val.eql(item_val, operand_ty)) {
                        return sema.resolveBlockBody(block, src, &child_block, body, merges);
                    }
                }

                var range_i: usize = 0;
                while (range_i < ranges_len) : (range_i += 1) {
                    const item_first = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const item_last = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;

                    // Validation above ensured these will succeed.
                    const first_tv = sema.resolveInstConst(&child_block, .unneeded, item_first) catch unreachable;
                    const last_tv = sema.resolveInstConst(&child_block, .unneeded, item_last) catch unreachable;
                    if (Value.compare(operand_val, .gte, first_tv.val, operand_ty) and
                        Value.compare(operand_val, .lte, last_tv.val, operand_ty))
                    {
                        return sema.resolveBlockBody(block, src, &child_block, body, merges);
                    }
                }

                extra_index += body_len;
            }
        }
        return sema.resolveBlockBody(block, src, &child_block, special.body, merges);
    }

    if (scalar_cases_len + multi_cases_len == 0) {
        return sema.resolveBlockBody(block, src, &child_block, special.body, merges);
    }

    try sema.requireRuntimeBlock(block, src);

    var cases_extra: std.ArrayListUnmanaged(u32) = .{};
    defer cases_extra.deinit(gpa);

    try cases_extra.ensureTotalCapacity(gpa, (scalar_cases_len + multi_cases_len) *
        @typeInfo(Air.SwitchBr.Case).Struct.fields.len + 2);

    var case_block = child_block.makeSubBlock();
    case_block.runtime_loop = null;
    case_block.runtime_cond = operand_src;
    case_block.runtime_index += 1;
    defer case_block.instructions.deinit(gpa);

    var extra_index: usize = special.end;

    var scalar_i: usize = 0;
    while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
        const item_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        const body_len = sema.code.extra[extra_index];
        extra_index += 1;
        const body = sema.code.extra[extra_index..][0..body_len];
        extra_index += body_len;

        var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, child_block.wip_capture_scope);
        defer wip_captures.deinit();

        case_block.instructions.shrinkRetainingCapacity(0);
        case_block.wip_capture_scope = wip_captures.scope;

        const item = sema.resolveInst(item_ref);
        // `item` is already guaranteed to be constant known.

        _ = try sema.analyzeBody(&case_block, body);

        try wip_captures.finalize();

        try cases_extra.ensureUnusedCapacity(gpa, 3 + case_block.instructions.items.len);
        cases_extra.appendAssumeCapacity(1); // items_len
        cases_extra.appendAssumeCapacity(@intCast(u32, case_block.instructions.items.len));
        cases_extra.appendAssumeCapacity(@enumToInt(item));
        cases_extra.appendSliceAssumeCapacity(case_block.instructions.items);
    }

    var is_first = true;
    var prev_cond_br: Air.Inst.Index = undefined;
    var first_else_body: []const Air.Inst.Index = &.{};
    defer gpa.free(first_else_body);
    var prev_then_body: []const Air.Inst.Index = &.{};
    defer gpa.free(prev_then_body);

    var cases_len = scalar_cases_len;
    var multi_i: usize = 0;
    while (multi_i < multi_cases_len) : (multi_i += 1) {
        const items_len = sema.code.extra[extra_index];
        extra_index += 1;
        const ranges_len = sema.code.extra[extra_index];
        extra_index += 1;
        const body_len = sema.code.extra[extra_index];
        extra_index += 1;
        const items = sema.code.refSlice(extra_index, items_len);
        extra_index += items_len;

        case_block.instructions.shrinkRetainingCapacity(0);
        case_block.wip_capture_scope = child_block.wip_capture_scope;

        var any_ok: Air.Inst.Ref = .none;

        // If there are any ranges, we have to put all the items into the
        // else prong. Otherwise, we can take advantage of multiple items
        // mapping to the same body.
        if (ranges_len == 0) {
            cases_len += 1;

            const body = sema.code.extra[extra_index..][0..body_len];
            extra_index += body_len;
            _ = try sema.analyzeBody(&case_block, body);

            try cases_extra.ensureUnusedCapacity(gpa, 2 + items.len +
                case_block.instructions.items.len);

            cases_extra.appendAssumeCapacity(@intCast(u32, items.len));
            cases_extra.appendAssumeCapacity(@intCast(u32, case_block.instructions.items.len));

            for (items) |item_ref| {
                const item = sema.resolveInst(item_ref);
                cases_extra.appendAssumeCapacity(@enumToInt(item));
            }

            cases_extra.appendSliceAssumeCapacity(case_block.instructions.items);
        } else {
            for (items) |item_ref| {
                const item = sema.resolveInst(item_ref);
                const cmp_ok = try case_block.addBinOp(.cmp_eq, operand, item);
                if (any_ok != .none) {
                    any_ok = try case_block.addBinOp(.bool_or, any_ok, cmp_ok);
                } else {
                    any_ok = cmp_ok;
                }
            }

            var range_i: usize = 0;
            while (range_i < ranges_len) : (range_i += 1) {
                const first_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                extra_index += 1;
                const last_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
                extra_index += 1;

                const item_first = sema.resolveInst(first_ref);
                const item_last = sema.resolveInst(last_ref);

                // operand >= first and operand <= last
                const range_first_ok = try case_block.addBinOp(
                    .cmp_gte,
                    operand,
                    item_first,
                );
                const range_last_ok = try case_block.addBinOp(
                    .cmp_lte,
                    operand,
                    item_last,
                );
                const range_ok = try case_block.addBinOp(
                    .bool_and,
                    range_first_ok,
                    range_last_ok,
                );
                if (any_ok != .none) {
                    any_ok = try case_block.addBinOp(.bool_or, any_ok, range_ok);
                } else {
                    any_ok = range_ok;
                }
            }

            const new_cond_br = try case_block.addInstAsIndex(.{ .tag = .cond_br, .data = .{
                .pl_op = .{
                    .operand = any_ok,
                    .payload = undefined,
                },
            } });
            var cond_body = case_block.instructions.toOwnedSlice(gpa);
            defer gpa.free(cond_body);

            var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, child_block.wip_capture_scope);
            defer wip_captures.deinit();

            case_block.instructions.shrinkRetainingCapacity(0);
            case_block.wip_capture_scope = wip_captures.scope;

            const body = sema.code.extra[extra_index..][0..body_len];
            extra_index += body_len;
            _ = try sema.analyzeBody(&case_block, body);

            try wip_captures.finalize();

            if (is_first) {
                is_first = false;
                first_else_body = cond_body;
                cond_body = &.{};
            } else {
                try sema.air_extra.ensureUnusedCapacity(
                    gpa,
                    @typeInfo(Air.CondBr).Struct.fields.len + prev_then_body.len + cond_body.len,
                );

                sema.air_instructions.items(.data)[prev_cond_br].pl_op.payload =
                    sema.addExtraAssumeCapacity(Air.CondBr{
                    .then_body_len = @intCast(u32, prev_then_body.len),
                    .else_body_len = @intCast(u32, cond_body.len),
                });
                sema.air_extra.appendSliceAssumeCapacity(prev_then_body);
                sema.air_extra.appendSliceAssumeCapacity(cond_body);
            }
            prev_then_body = case_block.instructions.toOwnedSlice(gpa);
            prev_cond_br = new_cond_br;
        }
    }

    var final_else_body: []const Air.Inst.Index = &.{};
    if (special.body.len != 0 or !is_first) {
        var wip_captures = try WipCaptureScope.init(gpa, sema.perm_arena, child_block.wip_capture_scope);
        defer wip_captures.deinit();

        case_block.instructions.shrinkRetainingCapacity(0);
        case_block.wip_capture_scope = wip_captures.scope;

        if (special.body.len != 0) {
            _ = try sema.analyzeBody(&case_block, special.body);
        } else {
            // We still need a terminator in this block, but we have proven
            // that it is unreachable.
            // TODO this should be a special safety panic other than unreachable, something
            // like "panic: switch operand had corrupt value not allowed by the type"
            try case_block.addUnreachable(src, true);
        }

        try wip_captures.finalize();

        if (is_first) {
            final_else_body = case_block.instructions.items;
        } else {
            try sema.air_extra.ensureUnusedCapacity(gpa, prev_then_body.len +
                @typeInfo(Air.CondBr).Struct.fields.len + case_block.instructions.items.len);

            sema.air_instructions.items(.data)[prev_cond_br].pl_op.payload =
                sema.addExtraAssumeCapacity(Air.CondBr{
                .then_body_len = @intCast(u32, prev_then_body.len),
                .else_body_len = @intCast(u32, case_block.instructions.items.len),
            });
            sema.air_extra.appendSliceAssumeCapacity(prev_then_body);
            sema.air_extra.appendSliceAssumeCapacity(case_block.instructions.items);
            final_else_body = first_else_body;
        }
    }

    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.SwitchBr).Struct.fields.len +
        cases_extra.items.len + final_else_body.len);

    _ = try child_block.addInst(.{ .tag = .switch_br, .data = .{ .pl_op = .{
        .operand = operand,
        .payload = sema.addExtraAssumeCapacity(Air.SwitchBr{
            .cases_len = @intCast(u32, cases_len),
            .else_body_len = @intCast(u32, final_else_body.len),
        }),
    } } });
    sema.air_extra.appendSliceAssumeCapacity(cases_extra.items);
    sema.air_extra.appendSliceAssumeCapacity(final_else_body);

    return sema.analyzeBlockBody(block, src, &child_block, merges);
}

fn resolveSwitchItemVal(
    sema: *Sema,
    block: *Block,
    item_ref: Zir.Inst.Ref,
    switch_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
    range_expand: Module.SwitchProngSrc.RangeExpand,
) CompileError!TypedValue {
    const item = sema.resolveInst(item_ref);
    const item_ty = sema.typeOf(item);
    // Constructing a LazySrcLoc is costly because we only have the switch AST node.
    // Only if we know for sure we need to report a compile error do we resolve the
    // full source locations.
    if (sema.resolveConstValue(block, .unneeded, item)) |val| {
        return TypedValue{ .ty = item_ty, .val = val };
    } else |err| switch (err) {
        error.NeededSourceLocation => {
            const src = switch_prong_src.resolve(sema.gpa, block.src_decl, switch_node_offset, range_expand);
            return TypedValue{
                .ty = item_ty,
                .val = try sema.resolveConstValue(block, src, item),
            };
        },
        else => |e| return e,
    }
}

fn validateSwitchRange(
    sema: *Sema,
    block: *Block,
    range_set: *RangeSet,
    first_ref: Zir.Inst.Ref,
    last_ref: Zir.Inst.Ref,
    operand_ty: Type,
    src_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
) CompileError!void {
    const first_val = (try sema.resolveSwitchItemVal(block, first_ref, src_node_offset, switch_prong_src, .first)).val;
    const last_val = (try sema.resolveSwitchItemVal(block, last_ref, src_node_offset, switch_prong_src, .last)).val;
    const maybe_prev_src = try range_set.add(first_val, last_val, operand_ty, switch_prong_src);
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchItem(
    sema: *Sema,
    block: *Block,
    range_set: *RangeSet,
    item_ref: Zir.Inst.Ref,
    operand_ty: Type,
    src_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
) CompileError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    const maybe_prev_src = try range_set.add(item_val, item_val, operand_ty, switch_prong_src);
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchItemEnum(
    sema: *Sema,
    block: *Block,
    seen_fields: []?Module.SwitchProngSrc,
    item_ref: Zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
) CompileError!void {
    const item_tv = try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none);
    const field_index = item_tv.ty.enumTagFieldIndex(item_tv.val) orelse {
        const msg = msg: {
            const src = switch_prong_src.resolve(sema.gpa, block.src_decl, src_node_offset, .none);
            const msg = try sema.errMsg(
                block,
                src,
                "enum '{}' has no tag with value '{}'",
                .{ item_tv.ty, item_tv.val },
            );
            errdefer msg.destroy(sema.gpa);
            try sema.mod.errNoteNonLazy(
                item_tv.ty.declSrcLoc(),
                msg,
                "enum declared here",
                .{},
            );
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    };
    const maybe_prev_src = seen_fields[field_index];
    seen_fields[field_index] = switch_prong_src;
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchDupe(
    sema: *Sema,
    block: *Block,
    maybe_prev_src: ?Module.SwitchProngSrc,
    switch_prong_src: Module.SwitchProngSrc,
    src_node_offset: i32,
) CompileError!void {
    const prev_prong_src = maybe_prev_src orelse return;
    const gpa = sema.gpa;
    const src = switch_prong_src.resolve(gpa, block.src_decl, src_node_offset, .none);
    const prev_src = prev_prong_src.resolve(gpa, block.src_decl, src_node_offset, .none);
    const msg = msg: {
        const msg = try sema.errMsg(
            block,
            src,
            "duplicate switch value",
            .{},
        );
        errdefer msg.destroy(sema.gpa);
        try sema.errNote(
            block,
            prev_src,
            msg,
            "previous value here",
            .{},
        );
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

fn validateSwitchItemBool(
    sema: *Sema,
    block: *Block,
    true_count: *u8,
    false_count: *u8,
    item_ref: Zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
) CompileError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    if (item_val.toBool()) {
        true_count.* += 1;
    } else {
        false_count.* += 1;
    }
    if (true_count.* + false_count.* > 2) {
        const src = switch_prong_src.resolve(sema.gpa, block.src_decl, src_node_offset, .none);
        return sema.fail(block, src, "duplicate switch value", .{});
    }
}

const ValueSrcMap = std.HashMap(Value, Module.SwitchProngSrc, Value.HashContext, std.hash_map.default_max_load_percentage);

fn validateSwitchItemSparse(
    sema: *Sema,
    block: *Block,
    seen_values: *ValueSrcMap,
    item_ref: Zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: Module.SwitchProngSrc,
) CompileError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    const kv = (try seen_values.fetchPut(item_val, switch_prong_src)) orelse return;
    return sema.validateSwitchDupe(block, kv.value, switch_prong_src, src_node_offset);
}

fn validateSwitchNoRange(
    sema: *Sema,
    block: *Block,
    ranges_len: u32,
    operand_ty: Type,
    src_node_offset: i32,
) CompileError!void {
    if (ranges_len == 0)
        return;

    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = src_node_offset };
    const range_src: LazySrcLoc = .{ .node_offset_switch_range = src_node_offset };

    const msg = msg: {
        const msg = try sema.errMsg(
            block,
            operand_src,
            "ranges not allowed when switching on type '{}'",
            .{operand_ty},
        );
        errdefer msg.destroy(sema.gpa);
        try sema.errNote(
            block,
            range_src,
            msg,
            "range here",
            .{},
        );
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

fn zirHasField(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const unresolved_ty = try sema.resolveType(block, ty_src, extra.lhs);
    const field_name = try sema.resolveConstString(block, name_src, extra.rhs);
    const ty = try sema.resolveTypeFields(block, ty_src, unresolved_ty);

    const has_field = hf: {
        if (ty.isSlice()) {
            if (mem.eql(u8, field_name, "ptr")) break :hf true;
            if (mem.eql(u8, field_name, "len")) break :hf true;
            break :hf false;
        }
        break :hf switch (ty.zigTypeTag()) {
            .Struct => ty.structFields().contains(field_name),
            .Union => ty.unionFields().contains(field_name),
            .Enum => ty.enumFields().contains(field_name),
            .Array => mem.eql(u8, field_name, "len"),
            else => return sema.fail(block, ty_src, "type '{}' does not support '@hasField'", .{
                ty,
            }),
        };
    };
    if (has_field) {
        return Air.Inst.Ref.bool_true;
    } else {
        return Air.Inst.Ref.bool_false;
    }
}

fn zirHasDecl(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const container_type = try sema.resolveType(block, lhs_src, extra.lhs);
    const decl_name = try sema.resolveConstString(block, rhs_src, extra.rhs);

    const namespace = container_type.getNamespace() orelse return sema.fail(
        block,
        lhs_src,
        "expected struct, enum, union, or opaque, found '{}'",
        .{container_type},
    );
    if (try sema.lookupInNamespace(block, src, namespace, decl_name, true)) |decl| {
        if (decl.is_pub or decl.getFileScope() == block.getFileScope()) {
            return Air.Inst.Ref.bool_true;
        }
    }
    return Air.Inst.Ref.bool_false;
}

fn zirImport(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = sema.mod;
    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const src = inst_data.src();
    const operand = inst_data.get(sema.code);

    const result = mod.importFile(block.getFileScope(), operand) catch |err| switch (err) {
        error.ImportOutsidePkgPath => {
            return sema.fail(block, src, "import of file outside package path: '{s}'", .{operand});
        },
        else => {
            // TODO: these errors are file system errors; make sure an update() will
            // retry this and not cache the file system error, which may be transient.
            return sema.fail(block, src, "unable to open '{s}': {s}", .{ operand, @errorName(err) });
        },
    };
    try mod.semaFile(result.file);
    const file_root_decl = result.file.root_decl.?;
    try mod.declareDeclDependency(sema.owner_decl, file_root_decl);
    return sema.addConstant(file_root_decl.ty, file_root_decl.val);
}

fn zirEmbedFile(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = sema.mod;
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const name = try sema.resolveConstString(block, src, inst_data.operand);

    const embed_file = mod.embedFile(block.getFileScope(), name) catch |err| switch (err) {
        error.ImportOutsidePkgPath => {
            return sema.fail(block, src, "embed of file outside package path: '{s}'", .{name});
        },
        else => {
            // TODO: these errors are file system errors; make sure an update() will
            // retry this and not cache the file system error, which may be transient.
            return sema.fail(block, src, "unable to open '{s}': {s}", .{ name, @errorName(err) });
        },
    };

    var anon_decl = try block.startAnonDecl();
    defer anon_decl.deinit();

    const bytes_including_null = embed_file.bytes[0 .. embed_file.bytes.len + 1];

    // TODO instead of using `Value.Tag.bytes`, create a new value tag for pointing at
    // a `*Module.EmbedFile`. The purpose of this would be:
    // - If only the length is read and the bytes are not inspected by comptime code,
    //   there can be an optimization where the codegen backend does a copy_file_range
    //   into the final binary, and never loads the data into memory.
    // - When a Decl is destroyed, it can free the `*Module.EmbedFile`.
    embed_file.owner_decl = try anon_decl.finish(
        try Type.Tag.array_u8_sentinel_0.create(anon_decl.arena(), embed_file.bytes.len),
        try Value.Tag.bytes.create(anon_decl.arena(), bytes_including_null),
    );

    return sema.analyzeDeclRef(embed_file.owner_decl);
}

fn zirRetErrValueCode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    _ = inst;
    return sema.fail(block, sema.src, "TODO implement zirRetErrValueCode", .{});
}

fn zirShl(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    air_tag: Air.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);

    // TODO coerce rhs if air_tag is not shl_sat

    const maybe_lhs_val = try sema.resolveMaybeUndefVal(block, lhs_src, lhs);
    const maybe_rhs_val = try sema.resolveMaybeUndefVal(block, rhs_src, rhs);

    const runtime_src = if (maybe_lhs_val) |lhs_val| rs: {
        const lhs_ty = sema.typeOf(lhs);

        if (lhs_val.isUndef()) return sema.addConstUndef(lhs_ty);
        const rhs_val = maybe_rhs_val orelse break :rs rhs_src;
        if (rhs_val.isUndef()) return sema.addConstUndef(lhs_ty);

        // If rhs is 0, return lhs without doing any calculations.
        if (rhs_val.compareWithZero(.eq)) {
            return sema.addConstant(lhs_ty, lhs_val);
        }
        const val = switch (air_tag) {
            .shl_exact => return sema.fail(block, lhs_src, "TODO implement Sema for comptime shl_exact", .{}),
            .shl_sat => try lhs_val.shlSat(rhs_val, lhs_ty, sema.arena, sema.mod.getTarget()),
            .shl => try lhs_val.shl(rhs_val, sema.arena),
            else => unreachable,
        };

        return sema.addConstant(lhs_ty, val);
    } else rs: {
        if (maybe_rhs_val) |rhs_val| {
            if (rhs_val.isUndef()) return sema.addConstUndef(sema.typeOf(lhs));
        }
        break :rs lhs_src;
    };

    // TODO: insert runtime safety check for shl_exact

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addBinOp(air_tag, lhs, rhs);
}

fn zirShr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);

    if (try sema.resolveMaybeUndefVal(block, lhs_src, lhs)) |lhs_val| {
        if (try sema.resolveMaybeUndefVal(block, rhs_src, rhs)) |rhs_val| {
            const lhs_ty = sema.typeOf(lhs);
            if (lhs_val.isUndef() or rhs_val.isUndef()) {
                return sema.addConstUndef(lhs_ty);
            }
            // If rhs is 0, return lhs without doing any calculations.
            if (rhs_val.compareWithZero(.eq)) {
                return sema.addConstant(lhs_ty, lhs_val);
            }
            const val = try lhs_val.shr(rhs_val, sema.arena);
            return sema.addConstant(lhs_ty, val);
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addBinOp(.shr, lhs, rhs);
}

fn zirBitwise(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    air_tag: Air.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);

    const instructions = &[_]Air.Inst.Ref{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions, .{ .override = &[_]LazySrcLoc{ lhs_src, rhs_src } });
    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    if (lhs_ty.zigTypeTag() == .Vector and rhs_ty.zigTypeTag() == .Vector) {
        if (lhs_ty.arrayLen() != rhs_ty.arrayLen()) {
            return sema.fail(block, src, "vector length mismatch: {d} and {d}", .{
                lhs_ty.arrayLen(),
                rhs_ty.arrayLen(),
            });
        }
        return sema.fail(block, src, "TODO implement support for vectors in zirBitwise", .{});
    } else if (lhs_ty.zigTypeTag() == .Vector or rhs_ty.zigTypeTag() == .Vector) {
        return sema.fail(block, src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs_ty,
            rhs_ty,
        });
    }

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;

    if (!is_int) {
        return sema.fail(block, src, "invalid operands to binary bitwise expression: '{s}' and '{s}'", .{ @tagName(lhs_ty.zigTypeTag()), @tagName(rhs_ty.zigTypeTag()) });
    }

    if (try sema.resolveMaybeUndefVal(block, lhs_src, casted_lhs)) |lhs_val| {
        if (try sema.resolveMaybeUndefVal(block, rhs_src, casted_rhs)) |rhs_val| {
            const result_val = switch (air_tag) {
                .bit_and => try lhs_val.bitwiseAnd(rhs_val, sema.arena),
                .bit_or => try lhs_val.bitwiseOr(rhs_val, sema.arena),
                .xor => try lhs_val.bitwiseXor(rhs_val, sema.arena),
                else => unreachable,
            };
            return sema.addConstant(scalar_type, result_val);
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addBinOp(air_tag, casted_lhs, casted_rhs);
}

fn zirBitNot(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src = src; // TODO put this on the operand, not the '~'

    const operand = sema.resolveInst(inst_data.operand);
    const operand_type = sema.typeOf(operand);
    const scalar_type = operand_type.scalarType();

    if (scalar_type.zigTypeTag() != .Int) {
        return sema.fail(block, src, "unable to perform binary not operation on type '{}'", .{operand_type});
    }

    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        const target = sema.mod.getTarget();
        if (val.isUndef()) {
            return sema.addConstUndef(scalar_type);
        } else if (operand_type.zigTypeTag() == .Vector) {
            const vec_len = operand_type.arrayLen();
            var elem_val_buf: Value.ElemValueBuffer = undefined;
            const elems = try sema.arena.alloc(Value, vec_len);
            for (elems) |*elem, i| {
                const elem_val = val.elemValueBuffer(i, &elem_val_buf);
                elem.* = try elem_val.bitwiseNot(scalar_type, sema.arena, target);
            }
            return sema.addConstant(
                operand_type,
                try Value.Tag.array.create(sema.arena, elems),
            );
        } else {
            const result_val = try val.bitwiseNot(scalar_type, sema.arena, target);
            return sema.addConstant(scalar_type, result_val);
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.not, operand_type, operand);
}

fn zirArrayCat(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };

    const lhs_info = getArrayCatInfo(lhs_ty) orelse
        return sema.fail(block, lhs_src, "expected array, found '{}'", .{lhs_ty});
    const rhs_info = getArrayCatInfo(rhs_ty) orelse
        return sema.fail(block, rhs_src, "expected array, found '{}'", .{rhs_ty});
    if (!lhs_info.elem_type.eql(rhs_info.elem_type)) {
        return sema.fail(block, rhs_src, "expected array of type '{}', found '{}'", .{ lhs_info.elem_type, rhs_ty });
    }

    // When there is a sentinel mismatch, no sentinel on the result. The type system
    // will catch this if it is a problem.
    var res_sent: ?Value = null;
    if (rhs_info.sentinel != null and lhs_info.sentinel != null) {
        if (rhs_info.sentinel.?.eql(lhs_info.sentinel.?, lhs_info.elem_type)) {
            res_sent = lhs_info.sentinel.?;
        }
    }

    if (try sema.resolveDefinedValue(block, lhs_src, lhs)) |lhs_val| {
        if (try sema.resolveDefinedValue(block, rhs_src, rhs)) |rhs_val| {
            const final_len = lhs_info.len + rhs_info.len;
            const final_len_including_sent = final_len + @boolToInt(res_sent != null);
            const is_pointer = lhs_ty.zigTypeTag() == .Pointer;
            const lhs_sub_val = if (is_pointer) (try sema.pointerDeref(block, lhs_src, lhs_val, lhs_ty)).? else lhs_val;
            const rhs_sub_val = if (is_pointer) (try sema.pointerDeref(block, rhs_src, rhs_val, rhs_ty)).? else rhs_val;
            var anon_decl = try block.startAnonDecl();
            defer anon_decl.deinit();

            const buf = try anon_decl.arena().alloc(Value, final_len_including_sent);
            {
                var i: u64 = 0;
                while (i < lhs_info.len) : (i += 1) {
                    const val = try lhs_sub_val.elemValue(sema.arena, i);
                    buf[i] = try val.copy(anon_decl.arena());
                }
            }
            {
                var i: u64 = 0;
                while (i < rhs_info.len) : (i += 1) {
                    const val = try rhs_sub_val.elemValue(sema.arena, i);
                    buf[lhs_info.len + i] = try val.copy(anon_decl.arena());
                }
            }
            const ty = if (res_sent) |rs| ty: {
                buf[final_len] = try rs.copy(anon_decl.arena());
                break :ty try Type.Tag.array_sentinel.create(anon_decl.arena(), .{
                    .len = final_len,
                    .elem_type = try lhs_info.elem_type.copy(anon_decl.arena()),
                    .sentinel = try rs.copy(anon_decl.arena()),
                });
            } else try Type.Tag.array.create(anon_decl.arena(), .{
                .len = final_len,
                .elem_type = try lhs_info.elem_type.copy(anon_decl.arena()),
            });
            const val = try Value.Tag.array.create(anon_decl.arena(), buf);
            const decl = try anon_decl.finish(ty, val);
            if (is_pointer) {
                return sema.analyzeDeclRef(decl);
            } else {
                return sema.analyzeDeclVal(block, .unneeded, decl);
            }
        } else {
            return sema.fail(block, lhs_src, "TODO runtime array_cat", .{});
        }
    } else {
        return sema.fail(block, lhs_src, "TODO runtime array_cat", .{});
    }
}

fn getArrayCatInfo(t: Type) ?Type.ArrayInfo {
    return switch (t.zigTypeTag()) {
        .Array => t.arrayInfo(),
        .Pointer => blk: {
            const ptrinfo = t.ptrInfo().data;
            if (ptrinfo.pointee_type.zigTypeTag() != .Array) return null;
            if (ptrinfo.size != .One) return null;
            break :blk ptrinfo.pointee_type.arrayInfo();
        },
        else => null,
    };
}

fn zirArrayMul(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const lhs_ty = sema.typeOf(lhs);
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };

    // In `**` rhs has to be comptime-known, but lhs can be runtime-known
    const factor = try sema.resolveInt(block, rhs_src, extra.rhs, Type.usize);
    const mulinfo = getArrayCatInfo(lhs_ty) orelse
        return sema.fail(block, lhs_src, "expected array, found '{}'", .{lhs_ty});

    const final_len = std.math.mul(u64, mulinfo.len, factor) catch
        return sema.fail(block, rhs_src, "operation results in overflow", .{});
    const final_len_including_sent = final_len + @boolToInt(mulinfo.sentinel != null);

    if (try sema.resolveDefinedValue(block, lhs_src, lhs)) |lhs_val| {
        const lhs_sub_val = if (lhs_ty.zigTypeTag() == .Pointer) (try sema.pointerDeref(block, lhs_src, lhs_val, lhs_ty)).? else lhs_val;

        var anon_decl = try block.startAnonDecl();
        defer anon_decl.deinit();

        const final_ty = if (mulinfo.sentinel) |sent|
            try Type.Tag.array_sentinel.create(anon_decl.arena(), .{
                .len = final_len,
                .elem_type = try mulinfo.elem_type.copy(anon_decl.arena()),
                .sentinel = try sent.copy(anon_decl.arena()),
            })
        else
            try Type.Tag.array.create(anon_decl.arena(), .{
                .len = final_len,
                .elem_type = try mulinfo.elem_type.copy(anon_decl.arena()),
            });
        const buf = try anon_decl.arena().alloc(Value, final_len_including_sent);

        // Optimization for the common pattern of a single element repeated N times, such
        // as zero-filling a byte array.
        const val = if (mulinfo.len == 1) blk: {
            const elem_val = try lhs_sub_val.elemValue(sema.arena, 0);
            const copied_val = try elem_val.copy(anon_decl.arena());
            break :blk try Value.Tag.repeated.create(anon_decl.arena(), copied_val);
        } else blk: {
            // the actual loop
            var i: u64 = 0;
            while (i < factor) : (i += 1) {
                var j: u64 = 0;
                while (j < mulinfo.len) : (j += 1) {
                    const val = try lhs_sub_val.elemValue(sema.arena, j);
                    buf[mulinfo.len * i + j] = try val.copy(anon_decl.arena());
                }
            }
            if (mulinfo.sentinel) |sent| {
                buf[final_len] = try sent.copy(anon_decl.arena());
            }
            break :blk try Value.Tag.array.create(anon_decl.arena(), buf);
        };
        const decl = try anon_decl.finish(final_ty, val);
        if (lhs_ty.zigTypeTag() == .Pointer) {
            return sema.analyzeDeclRef(decl);
        } else {
            return sema.analyzeDeclVal(block, .unneeded, decl);
        }
    }
    return sema.fail(block, lhs_src, "TODO runtime array_mul", .{});
}

fn zirNegate(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    tag_override: Zir.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const lhs_src = src;
    const rhs_src = src; // TODO better source location
    const lhs = sema.resolveInst(.zero);
    const rhs = sema.resolveInst(inst_data.operand);

    return sema.analyzeArithmetic(block, tag_override, lhs, rhs, src, lhs_src, rhs_src);
}

fn zirArithmetic(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    zir_tag: Zir.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    sema.src = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);

    return sema.analyzeArithmetic(block, zir_tag, lhs, rhs, sema.src, lhs_src, rhs_src);
}

fn zirOverflowArithmetic(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const extra = sema.code.extraData(Zir.Inst.OverflowArithmetic, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };

    return sema.fail(block, src, "TODO implement Sema.zirOverflowArithmetic", .{});
}

fn analyzeArithmetic(
    sema: *Sema,
    block: *Block,
    /// TODO performance investigation: make this comptime?
    zir_tag: Zir.Inst.Tag,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);
    const lhs_zig_ty_tag = try lhs_ty.zigTypeTagOrPoison();
    const rhs_zig_ty_tag = try rhs_ty.zigTypeTagOrPoison();
    if (lhs_zig_ty_tag == .Vector and rhs_zig_ty_tag == .Vector) {
        if (lhs_ty.arrayLen() != rhs_ty.arrayLen()) {
            return sema.fail(block, src, "vector length mismatch: {d} and {d}", .{
                lhs_ty.arrayLen(), rhs_ty.arrayLen(),
            });
        }
        return sema.fail(block, src, "TODO implement support for vectors in Sema.analyzeArithmetic", .{});
    } else if (lhs_zig_ty_tag == .Vector or rhs_zig_ty_tag == .Vector) {
        return sema.fail(block, src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs_ty, rhs_ty,
        });
    }
    if (lhs_zig_ty_tag == .Pointer) switch (lhs_ty.ptrSize()) {
        .One, .Slice => {},
        .Many, .C => {
            const op_src = src; // TODO better source location
            const air_tag: Air.Inst.Tag = switch (zir_tag) {
                .add => .ptr_add,
                .sub => .ptr_sub,
                else => return sema.fail(
                    block,
                    op_src,
                    "invalid pointer arithmetic operand: '{s}''",
                    .{@tagName(zir_tag)},
                ),
            };
            return analyzePtrArithmetic(sema, block, op_src, lhs, rhs, air_tag, lhs_src, rhs_src);
        },
    };

    const instructions = &[_]Air.Inst.Ref{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions, .{
        .override = &[_]LazySrcLoc{ lhs_src, rhs_src },
    });
    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;
    const is_float = scalar_tag == .Float or scalar_tag == .ComptimeFloat;

    if (!is_int and !(is_float and floatOpAllowed(zir_tag))) {
        return sema.fail(block, src, "invalid operands to binary expression: '{s}' and '{s}'", .{
            @tagName(lhs_zig_ty_tag), @tagName(rhs_zig_ty_tag),
        });
    }

    const target = sema.mod.getTarget();
    const maybe_lhs_val = try sema.resolveMaybeUndefVal(block, lhs_src, casted_lhs);
    const maybe_rhs_val = try sema.resolveMaybeUndefVal(block, rhs_src, casted_rhs);
    const rs: struct { src: LazySrcLoc, air_tag: Air.Inst.Tag } = rs: {
        switch (zir_tag) {
            .add => {
                // For integers:
                // If either of the operands are zero, then the other operand is
                // returned, even if it is undefined.
                // If either of the operands are undefined, it's a compile error
                // because there is a possible value for which the addition would
                // overflow (max_int), causing illegal behavior.
                // For floats: either operand being undef makes the result undef.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef() and lhs_val.compareWithZero(.eq)) {
                        return casted_rhs;
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        if (is_int) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        } else {
                            return sema.addConstUndef(scalar_type);
                        }
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        if (is_int) {
                            return sema.failWithUseOfUndef(block, lhs_src);
                        } else {
                            return sema.addConstUndef(scalar_type);
                        }
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intAdd(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatAdd(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = rhs_src, .air_tag = .add };
                } else break :rs .{ .src = lhs_src, .air_tag = .add };
            },
            .addwrap => {
                // Integers only; floats are checked above.
                // If either of the operands are zero, the other operand is returned.
                // If either of the operands are undefined, the result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef() and lhs_val.compareWithZero(.eq)) {
                        return casted_rhs;
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.numberAddWrap(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = lhs_src, .air_tag = .addwrap };
                } else break :rs .{ .src = rhs_src, .air_tag = .addwrap };
            },
            .add_sat => {
                // Integers only; floats are checked above.
                // If either of the operands are zero, then the other operand is returned.
                // If either of the operands are undefined, the result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef() and lhs_val.compareWithZero(.eq)) {
                        return casted_rhs;
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.intAddSat(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = lhs_src, .air_tag = .add_sat };
                } else break :rs .{ .src = rhs_src, .air_tag = .add_sat };
            },
            .sub => {
                // For integers:
                // If the rhs is zero, then the other operand is
                // returned, even if it is undefined.
                // If either of the operands are undefined, it's a compile error
                // because there is a possible value for which the subtraction would
                // overflow, causing illegal behavior.
                // For floats: either operand being undef makes the result undef.
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        if (is_int) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        } else {
                            return sema.addConstUndef(scalar_type);
                        }
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        if (is_int) {
                            return sema.failWithUseOfUndef(block, lhs_src);
                        } else {
                            return sema.addConstUndef(scalar_type);
                        }
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intSub(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatSub(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = rhs_src, .air_tag = .sub };
                } else break :rs .{ .src = lhs_src, .air_tag = .sub };
            },
            .subwrap => {
                // Integers only; floats are checked above.
                // If the RHS is zero, then the other operand is returned, even if it is undefined.
                // If either of the operands are undefined, the result is undefined.
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.numberSubWrap(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = rhs_src, .air_tag = .subwrap };
                } else break :rs .{ .src = lhs_src, .air_tag = .subwrap };
            },
            .sub_sat => {
                // Integers only; floats are checked above.
                // If the RHS is zero, result is LHS.
                // If either of the operands are undefined, result is undefined.
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return casted_lhs;
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.intSubSat(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = rhs_src, .air_tag = .sub_sat };
                } else break :rs .{ .src = lhs_src, .air_tag = .sub_sat };
            },
            .div => {
                // TODO: emit compile error when .div is used on integers and there would be an
                // ambiguous result between div_floor and div_trunc.

                // For integers:
                // If the lhs is zero, then zero is returned regardless of rhs.
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined:
                //   * if lhs type is signed:
                //     * if rhs is comptime-known and not -1, result is undefined
                //     * if rhs is -1 or runtime-known, compile error because there is a
                //        possible value (-min_int / -1)  for which division would be
                //        illegal behavior.
                //   * if lhs type is unsigned, undef is returned regardless of rhs.
                // TODO: emit runtime safety for division by zero
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        if (lhs_ty.isSignedInt() and rhs_ty.isSignedInt()) {
                            if (maybe_rhs_val) |rhs_val| {
                                if (rhs_val.compare(.neq, Value.negative_one, scalar_type)) {
                                    return sema.addConstUndef(scalar_type);
                                }
                            }
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        return sema.addConstUndef(scalar_type);
                    }

                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intDiv(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatDiv(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else {
                        if (is_int) {
                            break :rs .{ .src = rhs_src, .air_tag = .div_trunc };
                        } else {
                            break :rs .{ .src = rhs_src, .air_tag = .div_float };
                        }
                    }
                } else {
                    if (is_int) {
                        break :rs .{ .src = lhs_src, .air_tag = .div_trunc };
                    } else {
                        break :rs .{ .src = lhs_src, .air_tag = .div_float };
                    }
                }
            },
            .div_trunc => {
                // For integers:
                // If the lhs is zero, then zero is returned regardless of rhs.
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined:
                //   * if lhs type is signed:
                //     * if rhs is comptime-known and not -1, result is undefined
                //     * if rhs is -1 or runtime-known, compile error because there is a
                //        possible value (-min_int / -1)  for which division would be
                //        illegal behavior.
                //   * if lhs type is unsigned, undef is returned regardless of rhs.
                // TODO: emit runtime safety for division by zero
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        if (lhs_ty.isSignedInt() and rhs_ty.isSignedInt()) {
                            if (maybe_rhs_val) |rhs_val| {
                                if (rhs_val.compare(.neq, Value.negative_one, scalar_type)) {
                                    return sema.addConstUndef(scalar_type);
                                }
                            }
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        return sema.addConstUndef(scalar_type);
                    }

                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intDiv(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatDivTrunc(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = rhs_src, .air_tag = .div_trunc };
                } else break :rs .{ .src = lhs_src, .air_tag = .div_trunc };
            },
            .div_floor => {
                // For integers:
                // If the lhs is zero, then zero is returned regardless of rhs.
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined:
                //   * if lhs type is signed:
                //     * if rhs is comptime-known and not -1, result is undefined
                //     * if rhs is -1 or runtime-known, compile error because there is a
                //        possible value (-min_int / -1)  for which division would be
                //        illegal behavior.
                //   * if lhs type is unsigned, undef is returned regardless of rhs.
                // TODO: emit runtime safety for division by zero
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        if (lhs_ty.isSignedInt() and rhs_ty.isSignedInt()) {
                            if (maybe_rhs_val) |rhs_val| {
                                if (rhs_val.compare(.neq, Value.negative_one, scalar_type)) {
                                    return sema.addConstUndef(scalar_type);
                                }
                            }
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        return sema.addConstUndef(scalar_type);
                    }

                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intDivFloor(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatDivFloor(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = rhs_src, .air_tag = .div_floor };
                } else break :rs .{ .src = lhs_src, .air_tag = .div_floor };
            },
            .div_exact => {
                // For integers:
                // If the lhs is zero, then zero is returned regardless of rhs.
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, compile error because there is a possible
                // value for which the division would result in a remainder.
                // TODO: emit runtime safety for if there is a remainder
                // TODO: emit runtime safety for division by zero
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, compile error because there is a possible
                // value for which the division would result in a remainder.
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    } else {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (maybe_rhs_val) |rhs_val| {
                        if (is_int) {
                            // TODO: emit compile error if there is a remainder
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intDiv(rhs_val, sema.arena),
                            );
                        } else {
                            // TODO: emit compile error if there is a remainder
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatDiv(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = rhs_src, .air_tag = .div_exact };
                } else break :rs .{ .src = lhs_src, .air_tag = .div_exact };
            },
            .mul => {
                // For integers:
                // If either of the operands are zero, the result is zero.
                // If either of the operands are one, the result is the other
                // operand, even if it is undefined.
                // If either of the operands are undefined, it's a compile error
                // because there is a possible value for which the addition would
                // overflow (max_int), causing illegal behavior.
                // For floats: either operand being undef makes the result undef.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                        if (lhs_val.compare(.eq, Value.one, scalar_type)) {
                            return casted_rhs;
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        if (is_int) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        } else {
                            return sema.addConstUndef(scalar_type);
                        }
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.addConstant(scalar_type, Value.zero);
                    }
                    if (rhs_val.compare(.eq, Value.one, scalar_type)) {
                        return casted_lhs;
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            if (is_int) {
                                return sema.failWithUseOfUndef(block, lhs_src);
                            } else {
                                return sema.addConstUndef(scalar_type);
                            }
                        }
                        if (is_int) {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intMul(rhs_val, sema.arena),
                            );
                        } else {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.floatMul(rhs_val, scalar_type, sema.arena),
                            );
                        }
                    } else break :rs .{ .src = lhs_src, .air_tag = .mul };
                } else break :rs .{ .src = rhs_src, .air_tag = .mul };
            },
            .mulwrap => {
                // Integers only; floats are handled above.
                // If either of the operands are zero, result is zero.
                // If either of the operands are one, result is the other operand.
                // If either of the operands are undefined, result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                        if (lhs_val.compare(.eq, Value.one, scalar_type)) {
                            return casted_rhs;
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.addConstant(scalar_type, Value.zero);
                    }
                    if (rhs_val.compare(.eq, Value.one, scalar_type)) {
                        return casted_lhs;
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            return sema.addConstUndef(scalar_type);
                        }
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.numberMulWrap(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = lhs_src, .air_tag = .mulwrap };
                } else break :rs .{ .src = rhs_src, .air_tag = .mulwrap };
            },
            .mul_sat => {
                // Integers only; floats are checked above.
                // If either of the operands are zero, result is zero.
                // If either of the operands are one, result is the other operand.
                // If either of the operands are undefined, result is undefined.
                if (maybe_lhs_val) |lhs_val| {
                    if (!lhs_val.isUndef()) {
                        if (lhs_val.compareWithZero(.eq)) {
                            return sema.addConstant(scalar_type, Value.zero);
                        }
                        if (lhs_val.compare(.eq, Value.one, scalar_type)) {
                            return casted_rhs;
                        }
                    }
                }
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.addConstant(scalar_type, Value.zero);
                    }
                    if (rhs_val.compare(.eq, Value.one, scalar_type)) {
                        return casted_lhs;
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            return sema.addConstUndef(scalar_type);
                        }
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.intMulSat(rhs_val, scalar_type, sema.arena, target),
                        );
                    } else break :rs .{ .src = lhs_src, .air_tag = .mul_sat };
                } else break :rs .{ .src = rhs_src, .air_tag = .mul_sat };
            },
            .mod_rem => {
                // For integers:
                // Either operand being undef is a compile error because there exists
                // a possible value (TODO what is it?) that would invoke illegal behavior.
                // TODO: can lhs zero be handled better?
                // TODO: can lhs undef be handled better?
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                //
                // For either one: if the result would be different between @mod and @rem,
                // then emit a compile error saying you have to pick one.
                if (is_int) {
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, lhs_src);
                        }
                        if (lhs_val.compareWithZero(.lt)) {
                            return sema.failWithModRemNegative(block, lhs_src, lhs_ty, rhs_ty);
                        }
                    } else if (lhs_ty.isSignedInt()) {
                        return sema.failWithModRemNegative(block, lhs_src, lhs_ty, rhs_ty);
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        if (rhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        if (rhs_val.compareWithZero(.eq)) {
                            return sema.failWithDivideByZero(block, rhs_src);
                        }
                        if (rhs_val.compareWithZero(.lt)) {
                            return sema.failWithModRemNegative(block, rhs_src, lhs_ty, rhs_ty);
                        }
                        if (maybe_lhs_val) |lhs_val| {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intRem(rhs_val, sema.arena),
                            );
                        }
                        break :rs .{ .src = lhs_src, .air_tag = .rem };
                    } else if (rhs_ty.isSignedInt()) {
                        return sema.failWithModRemNegative(block, rhs_src, lhs_ty, rhs_ty);
                    } else {
                        break :rs .{ .src = rhs_src, .air_tag = .rem };
                    }
                }
                // float operands
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.lt)) {
                        return sema.failWithModRemNegative(block, rhs_src, lhs_ty, rhs_ty);
                    }
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef() or lhs_val.compareWithZero(.lt)) {
                            return sema.failWithModRemNegative(block, lhs_src, lhs_ty, rhs_ty);
                        }
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.floatRem(rhs_val, sema.arena),
                        );
                    } else {
                        return sema.failWithModRemNegative(block, lhs_src, lhs_ty, rhs_ty);
                    }
                } else {
                    return sema.failWithModRemNegative(block, rhs_src, lhs_ty, rhs_ty);
                }
            },
            .rem => {
                // For integers:
                // Either operand being undef is a compile error because there exists
                // a possible value (TODO what is it?) that would invoke illegal behavior.
                // TODO: can lhs zero be handled better?
                // TODO: can lhs undef be handled better?
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                if (is_int) {
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, lhs_src);
                        }
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        if (rhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        if (rhs_val.compareWithZero(.eq)) {
                            return sema.failWithDivideByZero(block, rhs_src);
                        }
                        if (maybe_lhs_val) |lhs_val| {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intRem(rhs_val, sema.arena),
                            );
                        }
                        break :rs .{ .src = lhs_src, .air_tag = .rem };
                    } else {
                        break :rs .{ .src = rhs_src, .air_tag = .rem };
                    }
                }
                // float operands
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.floatRem(rhs_val, sema.arena),
                        );
                    } else break :rs .{ .src = rhs_src, .air_tag = .rem };
                } else break :rs .{ .src = lhs_src, .air_tag = .rem };
            },
            .mod => {
                // For integers:
                // Either operand being undef is a compile error because there exists
                // a possible value (TODO what is it?) that would invoke illegal behavior.
                // TODO: can lhs zero be handled better?
                // TODO: can lhs undef be handled better?
                //
                // For floats:
                // If the rhs is zero, compile error for division by zero.
                // If the rhs is undefined, compile error because there is a possible
                // value (zero) for which the division would be illegal behavior.
                // If the lhs is undefined, result is undefined.
                if (is_int) {
                    if (maybe_lhs_val) |lhs_val| {
                        if (lhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, lhs_src);
                        }
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        if (rhs_val.isUndef()) {
                            return sema.failWithUseOfUndef(block, rhs_src);
                        }
                        if (rhs_val.compareWithZero(.eq)) {
                            return sema.failWithDivideByZero(block, rhs_src);
                        }
                        if (maybe_lhs_val) |lhs_val| {
                            return sema.addConstant(
                                scalar_type,
                                try lhs_val.intMod(rhs_val, sema.arena),
                            );
                        }
                        break :rs .{ .src = lhs_src, .air_tag = .mod };
                    } else {
                        break :rs .{ .src = rhs_src, .air_tag = .mod };
                    }
                }
                // float operands
                if (maybe_rhs_val) |rhs_val| {
                    if (rhs_val.isUndef()) {
                        return sema.failWithUseOfUndef(block, rhs_src);
                    }
                    if (rhs_val.compareWithZero(.eq)) {
                        return sema.failWithDivideByZero(block, rhs_src);
                    }
                }
                if (maybe_lhs_val) |lhs_val| {
                    if (lhs_val.isUndef()) {
                        return sema.addConstUndef(scalar_type);
                    }
                    if (maybe_rhs_val) |rhs_val| {
                        return sema.addConstant(
                            scalar_type,
                            try lhs_val.floatMod(rhs_val, sema.arena),
                        );
                    } else break :rs .{ .src = rhs_src, .air_tag = .mod };
                } else break :rs .{ .src = lhs_src, .air_tag = .mod };
            },
            else => unreachable,
        }
    };

    try sema.requireRuntimeBlock(block, rs.src);
    return block.addBinOp(rs.air_tag, casted_lhs, casted_rhs);
}

fn analyzePtrArithmetic(
    sema: *Sema,
    block: *Block,
    op_src: LazySrcLoc,
    ptr: Air.Inst.Ref,
    uncasted_offset: Air.Inst.Ref,
    air_tag: Air.Inst.Tag,
    ptr_src: LazySrcLoc,
    offset_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    // TODO if the operand is comptime-known to be negative, or is a negative int,
    // coerce to isize instead of usize.
    const offset = try sema.coerce(block, Type.usize, uncasted_offset, offset_src);
    // TODO adjust the return type according to alignment and other factors
    const runtime_src = rs: {
        if (try sema.resolveMaybeUndefVal(block, ptr_src, ptr)) |ptr_val| {
            if (try sema.resolveMaybeUndefVal(block, offset_src, offset)) |offset_val| {
                const ptr_ty = sema.typeOf(ptr);
                const new_ptr_ty = ptr_ty; // TODO modify alignment

                if (ptr_val.isUndef() or offset_val.isUndef()) {
                    return sema.addConstUndef(new_ptr_ty);
                }

                const offset_int = offset_val.toUnsignedInt();
                if (ptr_val.getUnsignedInt()) |addr| {
                    const target = sema.mod.getTarget();
                    const ptr_child_ty = ptr_ty.childType();
                    const elem_ty = if (ptr_ty.isSinglePointer() and ptr_child_ty.zigTypeTag() == .Array)
                        ptr_child_ty.childType()
                    else
                        ptr_child_ty;

                    const elem_size = elem_ty.abiSize(target);
                    const new_addr = switch (air_tag) {
                        .ptr_add => addr + elem_size * offset_int,
                        .ptr_sub => addr - elem_size * offset_int,
                        else => unreachable,
                    };
                    const new_ptr_val = try Value.Tag.int_u64.create(sema.arena, new_addr);
                    return sema.addConstant(new_ptr_ty, new_ptr_val);
                }
                if (air_tag == .ptr_sub) {
                    return sema.fail(block, op_src, "TODO implement Sema comptime pointer subtraction", .{});
                }
                const new_ptr_val = try ptr_val.elemPtr(sema.arena, offset_int);
                return sema.addConstant(new_ptr_ty, new_ptr_val);
            } else break :rs offset_src;
        } else break :rs ptr_src;
    };

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addBinOp(air_tag, ptr, offset);
}

fn zirLoad(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr_src: LazySrcLoc = .{ .node_offset_deref_ptr = inst_data.src_node };
    const ptr = sema.resolveInst(inst_data.operand);
    return sema.analyzeLoad(block, src, ptr, ptr_src);
}

fn zirAsm(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const extra = sema.code.extraData(Zir.Inst.Asm, extended.operand);
    const src: LazySrcLoc = .{ .node_offset = extra.data.src_node };
    const ret_ty_src: LazySrcLoc = .{ .node_offset_asm_ret_ty = extra.data.src_node };
    const outputs_len = @truncate(u5, extended.small);
    const inputs_len = @truncate(u5, extended.small >> 5);
    const clobbers_len = @truncate(u5, extended.small >> 10);

    if (outputs_len > 1) {
        return sema.fail(block, src, "TODO implement Sema for asm with more than 1 output", .{});
    }

    var extra_i = extra.end;
    var output_type_bits = extra.data.output_type_bits;

    const Output = struct { constraint: []const u8, ty: Type };
    const output: ?Output = if (outputs_len == 0) null else blk: {
        const output = sema.code.extraData(Zir.Inst.Asm.Output, extra_i);
        extra_i = output.end;

        const is_type = @truncate(u1, output_type_bits) != 0;
        output_type_bits >>= 1;

        if (!is_type) {
            return sema.fail(block, src, "TODO implement Sema for asm with non `->` output", .{});
        }

        const constraint = sema.code.nullTerminatedString(output.data.constraint);
        break :blk Output{
            .constraint = constraint,
            .ty = try sema.resolveType(block, ret_ty_src, output.data.operand),
        };
    };

    const args = try sema.arena.alloc(Air.Inst.Ref, inputs_len);
    const inputs = try sema.arena.alloc([]const u8, inputs_len);

    for (args) |*arg, arg_i| {
        const input = sema.code.extraData(Zir.Inst.Asm.Input, extra_i);
        extra_i = input.end;

        const name = sema.code.nullTerminatedString(input.data.name);
        _ = name; // TODO: use the name

        arg.* = sema.resolveInst(input.data.operand);
        inputs[arg_i] = sema.code.nullTerminatedString(input.data.constraint);
    }

    const clobbers = try sema.arena.alloc([]const u8, clobbers_len);
    for (clobbers) |*name| {
        name.* = sema.code.nullTerminatedString(sema.code.extra[extra_i]);
        extra_i += 1;
    }

    try sema.requireRuntimeBlock(block, src);
    const gpa = sema.gpa;
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Asm).Struct.fields.len + args.len);
    const asm_air = try block.addInst(.{
        .tag = .assembly,
        .data = .{ .ty_pl = .{
            .ty = if (output) |o| try sema.addType(o.ty) else Air.Inst.Ref.void_type,
            .payload = sema.addExtraAssumeCapacity(Air.Asm{
                .zir_index = inst,
            }),
        } },
    });
    sema.appendRefsAssumeCapacity(args);
    return asm_air;
}

/// Only called for equality operators. See also `zirCmp`.
fn zirCmpEq(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    op: std.math.CompareOperator,
    air_tag: Air.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);

    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);
    const lhs_ty_tag = lhs_ty.zigTypeTag();
    const rhs_ty_tag = rhs_ty.zigTypeTag();
    if (lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
        // null == null, null != null
        if (op == .eq) {
            return Air.Inst.Ref.bool_true;
        } else {
            return Air.Inst.Ref.bool_false;
        }
    }
    if (((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
        rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
    {
        // comparing null with optionals
        const opt_operand = if (lhs_ty_tag == .Null) rhs else lhs;
        return sema.analyzeIsNull(block, src, opt_operand, op == .neq);
    }
    if (((lhs_ty_tag == .Null and rhs_ty.isCPtr()) or (rhs_ty_tag == .Null and lhs_ty.isCPtr()))) {
        // comparing null with C pointers
        const opt_operand = if (lhs_ty_tag == .Null) rhs else lhs;
        return sema.analyzeIsNull(block, src, opt_operand, op == .neq);
    }
    if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
        const non_null_type = if (lhs_ty_tag == .Null) rhs_ty else lhs_ty;
        return sema.fail(block, src, "comparison of '{}' with null", .{non_null_type});
    }
    if (lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) {
        return sema.analyzeCmpUnionTag(block, rhs, rhs_src, lhs, lhs_src, op);
    }
    if (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union) {
        return sema.analyzeCmpUnionTag(block, lhs, lhs_src, rhs, rhs_src, op);
    }
    if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
        const runtime_src: LazySrcLoc = src: {
            if (try sema.resolveMaybeUndefVal(block, lhs_src, lhs)) |lval| {
                if (try sema.resolveMaybeUndefVal(block, rhs_src, rhs)) |rval| {
                    if (lval.isUndef() or rval.isUndef()) {
                        return sema.addConstUndef(Type.initTag(.bool));
                    }
                    // TODO optimisation opportunity: evaluate if mem.eql is faster with the names,
                    // or calling to Module.getErrorValue to get the values and then compare them is
                    // faster.
                    const lhs_name = lval.castTag(.@"error").?.data.name;
                    const rhs_name = rval.castTag(.@"error").?.data.name;
                    if (mem.eql(u8, lhs_name, rhs_name) == (op == .eq)) {
                        return Air.Inst.Ref.bool_true;
                    } else {
                        return Air.Inst.Ref.bool_false;
                    }
                } else {
                    break :src rhs_src;
                }
            } else {
                break :src lhs_src;
            }
        };
        try sema.requireRuntimeBlock(block, runtime_src);
        return block.addBinOp(air_tag, lhs, rhs);
    }
    if (lhs_ty_tag == .Type and rhs_ty_tag == .Type) {
        const lhs_as_type = try sema.analyzeAsType(block, lhs_src, lhs);
        const rhs_as_type = try sema.analyzeAsType(block, rhs_src, rhs);
        if (lhs_as_type.eql(rhs_as_type) == (op == .eq)) {
            return Air.Inst.Ref.bool_true;
        } else {
            return Air.Inst.Ref.bool_false;
        }
    }
    return sema.analyzeCmp(block, src, lhs, rhs, op, lhs_src, rhs_src, true);
}

fn analyzeCmpUnionTag(
    sema: *Sema,
    block: *Block,
    un: Air.Inst.Ref,
    un_src: LazySrcLoc,
    tag: Air.Inst.Ref,
    tag_src: LazySrcLoc,
    op: std.math.CompareOperator,
) CompileError!Air.Inst.Ref {
    const union_ty = try sema.resolveTypeFields(block, un_src, sema.typeOf(un));
    const union_tag_ty = union_ty.unionTagType() orelse {
        // TODO note at declaration site that says "union foo is not tagged"
        return sema.fail(block, un_src, "comparison of union and enum literal is only valid for tagged union types", .{});
    };
    // Coerce both the union and the tag to the union's tag type, and then execute the
    // enum comparison codepath.
    const coerced_tag = try sema.coerce(block, union_tag_ty, tag, tag_src);
    const coerced_union = try sema.coerce(block, union_tag_ty, un, un_src);

    return sema.cmpSelf(block, coerced_union, coerced_tag, op, un_src, tag_src);
}

/// Only called for non-equality operators. See also `zirCmpEq`.
fn zirCmp(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    op: std.math.CompareOperator,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    return sema.analyzeCmp(block, src, lhs, rhs, op, lhs_src, rhs_src, false);
}

fn analyzeCmp(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
    op: std.math.CompareOperator,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
    is_equality_cmp: bool,
) CompileError!Air.Inst.Ref {
    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);
    if (lhs_ty.isNumeric() and rhs_ty.isNumeric()) {
        // This operation allows any combination of integer and float types, regardless of the
        // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
        // numeric types.
        return sema.cmpNumeric(block, src, lhs, rhs, op, lhs_src, rhs_src);
    }
    const instructions = &[_]Air.Inst.Ref{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions, .{ .override = &[_]LazySrcLoc{ lhs_src, rhs_src } });
    if (!resolved_type.isSelfComparable(is_equality_cmp)) {
        return sema.fail(block, src, "{s} operator not allowed for type '{}'", .{
            @tagName(op), resolved_type,
        });
    }
    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);
    return sema.cmpSelf(block, casted_lhs, casted_rhs, op, lhs_src, rhs_src);
}

fn cmpSelf(
    sema: *Sema,
    block: *Block,
    casted_lhs: Air.Inst.Ref,
    casted_rhs: Air.Inst.Ref,
    op: std.math.CompareOperator,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const resolved_type = sema.typeOf(casted_lhs);
    const runtime_src: LazySrcLoc = src: {
        if (try sema.resolveMaybeUndefVal(block, lhs_src, casted_lhs)) |lhs_val| {
            if (lhs_val.isUndef()) return sema.addConstUndef(resolved_type);
            if (try sema.resolveMaybeUndefVal(block, rhs_src, casted_rhs)) |rhs_val| {
                if (rhs_val.isUndef()) return sema.addConstUndef(resolved_type);

                if (lhs_val.compare(op, rhs_val, resolved_type)) {
                    return Air.Inst.Ref.bool_true;
                } else {
                    return Air.Inst.Ref.bool_false;
                }
            } else {
                if (resolved_type.zigTypeTag() == .Bool) {
                    // We can lower bool eq/neq more efficiently.
                    return sema.runtimeBoolCmp(block, op, casted_rhs, lhs_val.toBool(), rhs_src);
                }
                break :src rhs_src;
            }
        } else {
            // For bools, we still check the other operand, because we can lower
            // bool eq/neq more efficiently.
            if (resolved_type.zigTypeTag() == .Bool) {
                if (try sema.resolveMaybeUndefVal(block, rhs_src, casted_rhs)) |rhs_val| {
                    if (rhs_val.isUndef()) return sema.addConstUndef(resolved_type);
                    return sema.runtimeBoolCmp(block, op, casted_lhs, rhs_val.toBool(), lhs_src);
                }
            }
            break :src lhs_src;
        }
    };
    try sema.requireRuntimeBlock(block, runtime_src);

    const tag: Air.Inst.Tag = switch (op) {
        .lt => .cmp_lt,
        .lte => .cmp_lte,
        .eq => .cmp_eq,
        .gte => .cmp_gte,
        .gt => .cmp_gt,
        .neq => .cmp_neq,
    };
    // TODO handle vectors
    return block.addBinOp(tag, casted_lhs, casted_rhs);
}

/// cmp_eq (x, false) => not(x)
/// cmp_eq (x, true ) => x
/// cmp_neq(x, false) => x
/// cmp_neq(x, true ) => not(x)
fn runtimeBoolCmp(
    sema: *Sema,
    block: *Block,
    op: std.math.CompareOperator,
    lhs: Air.Inst.Ref,
    rhs: bool,
    runtime_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    if ((op == .neq) == rhs) {
        try sema.requireRuntimeBlock(block, runtime_src);
        return block.addTyOp(.not, Type.initTag(.bool), lhs);
    } else {
        return lhs;
    }
}

fn zirSizeOf(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_ty = try sema.resolveType(block, operand_src, inst_data.operand);
    try sema.resolveTypeLayout(block, src, operand_ty);
    const target = sema.mod.getTarget();
    const abi_size = switch (operand_ty.zigTypeTag()) {
        .Fn => unreachable,
        .NoReturn,
        .Undefined,
        .Null,
        .BoundFn,
        .Opaque,
        => return sema.fail(block, src, "no size available for type '{}'", .{operand_ty}),
        .Type,
        .EnumLiteral,
        .ComptimeFloat,
        .ComptimeInt,
        .Void,
        => 0,

        .Bool,
        .Int,
        .Float,
        .Pointer,
        .Array,
        .Struct,
        .Optional,
        .ErrorUnion,
        .ErrorSet,
        .Enum,
        .Union,
        .Vector,
        .Frame,
        .AnyFrame,
        => operand_ty.abiSize(target),
    };
    return sema.addIntUnsigned(Type.initTag(.comptime_int), abi_size);
}

fn zirBitSizeOf(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_ty = try sema.resolveType(block, operand_src, inst_data.operand);
    const target = sema.mod.getTarget();
    const bit_size = operand_ty.bitSize(target);
    return sema.addIntUnsigned(Type.initTag(.comptime_int), bit_size);
}

fn zirThis(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const this_decl = block.namespace.getDecl();
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.analyzeDeclVal(block, src, this_decl);
}

fn zirClosureCapture(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!void {
    // TODO: Compile error when closed over values are modified
    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const tv = try sema.resolveInstConst(block, inst_data.src(), inst_data.operand);
    try block.wip_capture_scope.captures.putNoClobber(sema.gpa, inst, .{
        .ty = try tv.ty.copy(sema.perm_arena),
        .val = try tv.val.copy(sema.perm_arena),
    });
}

fn zirClosureGet(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    // TODO CLOSURE: Test this with inline functions
    const inst_data = sema.code.instructions.items(.data)[inst].inst_node;
    var scope: *CaptureScope = block.src_decl.src_scope.?;
    // Note: The target closure must be in this scope list.
    // If it's not here, the zir is invalid, or the list is broken.
    const tv = while (true) {
        // Note: We don't need to add a dependency here, because
        // decls always depend on their lexical parents.
        if (scope.captures.getPtr(inst_data.inst)) |tv| {
            break tv;
        }
        scope = scope.parent.?;
    } else unreachable;

    return sema.addConstant(tv.ty, tv.val);
}

fn zirRetAddr(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.fail(block, src, "TODO: implement Sema.zirRetAddr", .{});
}

fn zirBuiltinSrc(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.fail(block, src, "TODO: implement Sema.zirBuiltinSrc", .{});
}

fn zirTypeInfo(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ty = try sema.resolveType(block, src, inst_data.operand);
    const type_info_ty = try sema.getBuiltinType(block, src, "TypeInfo");
    const target = sema.mod.getTarget();

    switch (ty.zigTypeTag()) {
        .Type => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Type)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .Void => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Void)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .Bool => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Bool)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .NoReturn => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.NoReturn)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .ComptimeFloat => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.ComptimeFloat)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .ComptimeInt => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.ComptimeInt)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .Undefined => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Undefined)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .Null => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Null)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .EnumLiteral => return sema.addConstant(
            type_info_ty,
            try Value.Tag.@"union".create(sema.arena, .{
                .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.EnumLiteral)),
                .val = Value.initTag(.unreachable_value),
            }),
        ),
        .Fn => {
            const info = ty.fnInfo();
            const field_values = try sema.arena.alloc(Value, 6);
            // calling_convention: CallingConvention,
            field_values[0] = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(info.cc));
            // alignment: comptime_int,
            field_values[1] = try Value.Tag.int_u64.create(sema.arena, ty.abiAlignment(target));
            // is_generic: bool,
            field_values[2] = if (info.is_generic) Value.initTag(.bool_true) else Value.initTag(.bool_false);
            // is_var_args: bool,
            field_values[3] = if (info.is_var_args) Value.initTag(.bool_true) else Value.initTag(.bool_false);
            // return_type: ?type,
            field_values[4] = try Value.Tag.ty.create(sema.arena, ty.fnReturnType());
            // args: []const FnArg,
            field_values[5] = Value.@"null"; // TODO

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Fn)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .Int => {
            const info = ty.intInfo(target);
            const field_values = try sema.arena.alloc(Value, 2);
            // signedness: Signedness,
            field_values[0] = try Value.Tag.enum_field_index.create(
                sema.arena,
                @enumToInt(info.signedness),
            );
            // bits: comptime_int,
            field_values[1] = try Value.Tag.int_u64.create(sema.arena, info.bits);

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Int)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .Float => {
            const field_values = try sema.arena.alloc(Value, 1);
            // bits: comptime_int,
            field_values[0] = try Value.Tag.int_u64.create(sema.arena, ty.bitSize(target));

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Float)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .Pointer => {
            const info = ty.ptrInfo().data;
            const field_values = try sema.arena.alloc(Value, 7);
            // size: Size,
            field_values[0] = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(info.size));
            // is_const: bool,
            field_values[1] = if (!info.mutable) Value.initTag(.bool_true) else Value.initTag(.bool_false);
            // is_volatile: bool,
            field_values[2] = if (info.@"volatile") Value.initTag(.bool_true) else Value.initTag(.bool_false);
            // alignment: comptime_int,
            field_values[3] = try Value.Tag.int_u64.create(sema.arena, info.@"align");
            // child: type,
            field_values[4] = try Value.Tag.ty.create(sema.arena, info.pointee_type);
            // is_allowzero: bool,
            field_values[5] = if (info.@"allowzero") Value.initTag(.bool_true) else Value.initTag(.bool_false);
            // sentinel: anytype,
            field_values[6] = if (info.sentinel) |some| try Value.Tag.opt_payload.create(sema.arena, some) else Value.@"null";

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Pointer)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .Array => {
            const info = ty.arrayInfo();
            const field_values = try sema.arena.alloc(Value, 3);
            // len: comptime_int,
            field_values[0] = try Value.Tag.int_u64.create(sema.arena, info.len);
            // child: type,
            field_values[1] = try Value.Tag.ty.create(sema.arena, info.elem_type);
            // sentinel: anytype,
            field_values[2] = if (info.sentinel) |some| try Value.Tag.opt_payload.create(sema.arena, some) else Value.@"null";

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Array)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .Optional => {
            const field_values = try sema.arena.alloc(Value, 1);
            // child: type,
            field_values[0] = try Value.Tag.ty.create(sema.arena, try ty.optionalChildAlloc(sema.arena));

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.Optional)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        .ErrorUnion => {
            const field_values = try sema.arena.alloc(Value, 2);
            // error_set: type,
            field_values[0] = try Value.Tag.ty.create(sema.arena, ty.errorUnionSet());
            // payload: type,
            field_values[1] = try Value.Tag.ty.create(sema.arena, ty.errorUnionPayload());

            return sema.addConstant(
                type_info_ty,
                try Value.Tag.@"union".create(sema.arena, .{
                    .tag = try Value.Tag.enum_field_index.create(sema.arena, @enumToInt(std.builtin.TypeId.ErrorUnion)),
                    .val = try Value.Tag.@"struct".create(sema.arena, field_values),
                }),
            );
        },
        else => |t| return sema.fail(block, src, "TODO: implement zirTypeInfo for {s}", .{
            @tagName(t),
        }),
    }
}

fn zirTypeof(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    _ = block;
    const zir_datas = sema.code.instructions.items(.data);
    const inst_data = zir_datas[inst].un_node;
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    return sema.addType(operand_ty);
}

fn zirTypeofLog2IntType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    return sema.log2IntType(block, operand_ty, src);
}

fn zirLog2IntType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveType(block, src, inst_data.operand);
    return sema.log2IntType(block, operand, src);
}

fn log2IntType(sema: *Sema, block: *Block, operand: Type, src: LazySrcLoc) CompileError!Air.Inst.Ref {
    switch (operand.zigTypeTag()) {
        .ComptimeInt => return Air.Inst.Ref.comptime_int_type,
        .Int => {
            var count: u16 = 0;
            var s = operand.bitSize(sema.mod.getTarget()) - 1;
            while (s != 0) : (s >>= 1) {
                count += 1;
            }
            const res = try Module.makeIntType(sema.arena, .unsigned, count);
            return sema.addType(res);
        },
        else => return sema.fail(
            block,
            src,
            "bit shifting operation expected integer type, found '{}'",
            .{operand},
        ),
    }
}

fn zirTypeofPeer(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const extra = sema.code.extraData(Zir.Inst.NodeMultiOp, extended.operand);
    const src: LazySrcLoc = .{ .node_offset = extra.data.src_node };
    const args = sema.code.refSlice(extra.end, extended.small);

    const inst_list = try sema.gpa.alloc(Air.Inst.Ref, args.len);
    defer sema.gpa.free(inst_list);

    for (args) |arg_ref, i| {
        inst_list[i] = sema.resolveInst(arg_ref);
    }

    const result_type = try sema.resolvePeerTypes(block, src, inst_list, .{ .typeof_builtin_call_node_offset = extra.data.src_node });
    return sema.addType(result_type);
}

fn zirBoolNot(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src = src; // TODO put this on the operand, not the `!`
    const uncasted_operand = sema.resolveInst(inst_data.operand);

    const bool_type = Type.initTag(.bool);
    const operand = try sema.coerce(block, bool_type, uncasted_operand, operand_src);
    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        return if (val.isUndef())
            sema.addConstUndef(bool_type)
        else if (val.toBool())
            Air.Inst.Ref.bool_false
        else
            Air.Inst.Ref.bool_true;
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.not, bool_type, operand);
}

fn zirBoolBr(
    sema: *Sema,
    parent_block: *Block,
    inst: Zir.Inst.Index,
    is_bool_or: bool,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const datas = sema.code.instructions.items(.data);
    const inst_data = datas[inst].bool_br;
    const lhs = sema.resolveInst(inst_data.lhs);
    const lhs_src = sema.src;
    const extra = sema.code.extraData(Zir.Inst.Block, inst_data.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];
    const gpa = sema.gpa;

    if (try sema.resolveDefinedValue(parent_block, lhs_src, lhs)) |lhs_val| {
        if (lhs_val.toBool() == is_bool_or) {
            if (is_bool_or) {
                return Air.Inst.Ref.bool_true;
            } else {
                return Air.Inst.Ref.bool_false;
            }
        }
        // comptime-known left-hand side. No need for a block here; the result
        // is simply the rhs expression. Here we rely on there only being 1
        // break instruction (`break_inline`).
        return sema.resolveBody(parent_block, body);
    }

    const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
    try sema.air_instructions.append(gpa, .{
        .tag = .block,
        .data = .{ .ty_pl = .{
            .ty = .bool_type,
            .payload = undefined,
        } },
    });

    var child_block = parent_block.makeSubBlock();
    child_block.runtime_loop = null;
    child_block.runtime_cond = lhs_src;
    child_block.runtime_index += 1;
    defer child_block.instructions.deinit(gpa);

    var then_block = child_block.makeSubBlock();
    defer then_block.instructions.deinit(gpa);

    var else_block = child_block.makeSubBlock();
    defer else_block.instructions.deinit(gpa);

    const lhs_block = if (is_bool_or) &then_block else &else_block;
    const rhs_block = if (is_bool_or) &else_block else &then_block;

    const lhs_result: Air.Inst.Ref = if (is_bool_or) .bool_true else .bool_false;
    _ = try lhs_block.addBr(block_inst, lhs_result);

    const rhs_result = try sema.resolveBody(rhs_block, body);
    _ = try rhs_block.addBr(block_inst, rhs_result);

    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.CondBr).Struct.fields.len +
        then_block.instructions.items.len + else_block.instructions.items.len +
        @typeInfo(Air.Block).Struct.fields.len + child_block.instructions.items.len + 1);

    const cond_br_payload = sema.addExtraAssumeCapacity(Air.CondBr{
        .then_body_len = @intCast(u32, then_block.instructions.items.len),
        .else_body_len = @intCast(u32, else_block.instructions.items.len),
    });
    sema.air_extra.appendSliceAssumeCapacity(then_block.instructions.items);
    sema.air_extra.appendSliceAssumeCapacity(else_block.instructions.items);

    _ = try child_block.addInst(.{ .tag = .cond_br, .data = .{ .pl_op = .{
        .operand = lhs,
        .payload = cond_br_payload,
    } } });

    sema.air_instructions.items(.data)[block_inst].ty_pl.payload = sema.addExtraAssumeCapacity(
        Air.Block{ .body_len = @intCast(u32, child_block.instructions.items.len) },
    );
    sema.air_extra.appendSliceAssumeCapacity(child_block.instructions.items);

    try parent_block.instructions.append(gpa, block_inst);
    return Air.indexToRef(block_inst);
}

fn zirIsNonNull(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = sema.resolveInst(inst_data.operand);
    return sema.analyzeIsNull(block, src, operand, true);
}

fn zirIsNonNullPtr(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr = sema.resolveInst(inst_data.operand);
    const loaded = try sema.analyzeLoad(block, src, ptr, src);
    return sema.analyzeIsNull(block, src, loaded, true);
}

fn zirIsNonErr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = sema.resolveInst(inst_data.operand);
    return sema.analyzeIsNonErr(block, inst_data.src(), operand);
}

fn zirIsNonErrPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr = sema.resolveInst(inst_data.operand);
    const loaded = try sema.analyzeLoad(block, src, ptr, src);
    return sema.analyzeIsNonErr(block, src, loaded);
}

fn zirCondbr(
    sema: *Sema,
    parent_block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const cond_src: LazySrcLoc = .{ .node_offset_if_cond = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.CondBr, inst_data.payload_index);

    const then_body = sema.code.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = sema.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];

    const uncasted_cond = sema.resolveInst(extra.data.condition);
    const cond = try sema.coerce(parent_block, Type.initTag(.bool), uncasted_cond, cond_src);

    if (try sema.resolveDefinedValue(parent_block, src, cond)) |cond_val| {
        const body = if (cond_val.toBool()) then_body else else_body;
        _ = try sema.analyzeBody(parent_block, body);
        return always_noreturn;
    }

    const gpa = sema.gpa;

    // We'll re-use the sub block to save on memory bandwidth, and yank out the
    // instructions array in between using it for the then block and else block.
    var sub_block = parent_block.makeSubBlock();
    sub_block.runtime_loop = null;
    sub_block.runtime_cond = cond_src;
    sub_block.runtime_index += 1;
    defer sub_block.instructions.deinit(gpa);

    _ = try sema.analyzeBody(&sub_block, then_body);
    const true_instructions = sub_block.instructions.toOwnedSlice(gpa);
    defer gpa.free(true_instructions);

    _ = try sema.analyzeBody(&sub_block, else_body);
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.CondBr).Struct.fields.len +
        true_instructions.len + sub_block.instructions.items.len);
    _ = try parent_block.addInst(.{
        .tag = .cond_br,
        .data = .{ .pl_op = .{
            .operand = cond,
            .payload = sema.addExtraAssumeCapacity(Air.CondBr{
                .then_body_len = @intCast(u32, true_instructions.len),
                .else_body_len = @intCast(u32, sub_block.instructions.items.len),
            }),
        } },
    });
    sema.air_extra.appendSliceAssumeCapacity(true_instructions);
    sema.air_extra.appendSliceAssumeCapacity(sub_block.instructions.items);
    return always_noreturn;
}

fn zirUnreachable(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].@"unreachable";
    const src = inst_data.src();
    try sema.requireRuntimeBlock(block, src);
    // TODO Add compile error for @optimizeFor occurring too late in a scope.
    try block.addUnreachable(src, inst_data.safety);
    return always_noreturn;
}

fn zirRetErrValue(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Zir.Inst.Index {
    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const err_name = inst_data.get(sema.code);
    const src = inst_data.src();

    // Return the error code from the function.
    const kv = try sema.mod.getErrorValue(err_name);
    const result_inst = try sema.addConstant(
        try Type.Tag.error_set_single.create(sema.arena, kv.key),
        try Value.Tag.@"error".create(sema.arena, .{ .name = kv.key }),
    );
    return sema.analyzeRet(block, result_inst, src);
}

fn zirRetCoerce(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const operand = sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.analyzeRet(block, operand, src);
}

fn zirRetNode(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.analyzeRet(block, operand, src);
}

fn zirRetLoad(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ret_ptr = sema.resolveInst(inst_data.operand);

    if (block.is_comptime or block.inlining != null) {
        const operand = try sema.analyzeLoad(block, src, ret_ptr, src);
        return sema.analyzeRet(block, operand, src);
    }
    try sema.requireRuntimeBlock(block, src);
    _ = try block.addUnOp(.ret_load, ret_ptr);
    return always_noreturn;
}

fn analyzeRet(
    sema: *Sema,
    block: *Block,
    uncasted_operand: Air.Inst.Ref,
    src: LazySrcLoc,
) CompileError!Zir.Inst.Index {
    // Special case for returning an error to an inferred error set; we need to
    // add the error tag to the inferred error set of the in-scope function, so
    // that the coercion below works correctly.
    if (sema.fn_ret_ty.zigTypeTag() == .ErrorUnion) {
        if (sema.fn_ret_ty.errorUnionSet().castTag(.error_set_inferred)) |payload| {
            const op_ty = sema.typeOf(uncasted_operand);
            switch (op_ty.zigTypeTag()) {
                .ErrorSet => {
                    try payload.data.addErrorSet(sema.gpa, op_ty);
                },
                .ErrorUnion => {
                    try payload.data.addErrorSet(sema.gpa, op_ty.errorUnionSet());
                },
                else => {},
            }
        }
    }
    const operand = try sema.coerce(block, sema.fn_ret_ty, uncasted_operand, src);

    if (block.inlining) |inlining| {
        if (block.is_comptime) {
            inlining.comptime_result = operand;
            return error.ComptimeReturn;
        }
        // We are inlining a function call; rewrite the `ret` as a `break`.
        try inlining.merges.results.append(sema.gpa, operand);
        _ = try block.addBr(inlining.merges.block_inst, operand);
        return always_noreturn;
    }

    try sema.resolveTypeLayout(block, src, sema.fn_ret_ty);
    _ = try block.addUnOp(.ret, operand);
    return always_noreturn;
}

fn floatOpAllowed(tag: Zir.Inst.Tag) bool {
    // extend this swich as additional operators are implemented
    return switch (tag) {
        .add, .sub, .mul, .div, .div_exact, .div_trunc, .div_floor, .mod, .rem, .mod_rem => true,
        else => false,
    };
}

fn zirPtrTypeSimple(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].ptr_type_simple;
    const elem_type = try sema.resolveType(block, .unneeded, inst_data.elem_type);
    const ty = try Type.ptr(sema.arena, .{
        .pointee_type = elem_type,
        .@"addrspace" = .generic,
        .mutable = inst_data.is_mutable,
        .@"allowzero" = inst_data.is_allowzero or inst_data.size == .C,
        .@"volatile" = inst_data.is_volatile,
        .size = inst_data.size,
    });
    return sema.addType(ty);
}

fn zirPtrType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    const inst_data = sema.code.instructions.items(.data)[inst].ptr_type;
    const extra = sema.code.extraData(Zir.Inst.PtrType, inst_data.payload_index);

    var extra_i = extra.end;

    const sentinel = if (inst_data.flags.has_sentinel) blk: {
        const ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk (try sema.resolveInstConst(block, .unneeded, ref)).val;
    } else null;

    const abi_align = if (inst_data.flags.has_align) blk: {
        const ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u32);
    } else 0;

    const address_space = if (inst_data.flags.has_addrspace) blk: {
        const ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.analyzeAddrspace(block, .unneeded, ref, .pointer);
    } else .generic;

    const bit_start = if (inst_data.flags.has_bit_range) blk: {
        const ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u16);
    } else 0;

    const bit_end = if (inst_data.flags.has_bit_range) blk: {
        const ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u16);
    } else 0;

    if (bit_end != 0 and bit_start >= bit_end * 8)
        return sema.fail(block, src, "bit offset starts after end of host integer", .{});

    const elem_type = try sema.resolveType(block, .unneeded, extra.data.elem_type);

    const ty = try Type.ptr(sema.arena, .{
        .pointee_type = elem_type,
        .sentinel = sentinel,
        .@"align" = abi_align,
        .@"addrspace" = address_space,
        .bit_offset = bit_start,
        .host_size = bit_end,
        .mutable = inst_data.flags.is_mutable,
        .@"allowzero" = inst_data.flags.is_allowzero or inst_data.size == .C,
        .@"volatile" = inst_data.flags.is_volatile,
        .size = inst_data.size,
    });
    return sema.addType(ty);
}

fn zirStructInitEmpty(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const obj_ty = try sema.resolveType(block, src, inst_data.operand);

    switch (obj_ty.zigTypeTag()) {
        .Struct => return sema.addConstant(obj_ty, Value.initTag(.empty_struct_value)),
        .Array => {
            if (obj_ty.sentinel()) |sentinel| {
                const val = try Value.Tag.empty_array_sentinel.create(sema.arena, sentinel);
                return sema.addConstant(obj_ty, val);
            } else {
                return sema.addConstant(obj_ty, Value.initTag(.empty_array));
            }
        },
        .Void => return sema.addConstant(obj_ty, Value.void),
        else => unreachable,
    }
}

fn zirUnionInitPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirUnionInitPtr", .{});
}

fn zirStructInit(sema: *Sema, block: *Block, inst: Zir.Inst.Index, is_ref: bool) CompileError!Air.Inst.Ref {
    const gpa = sema.gpa;
    const zir_datas = sema.code.instructions.items(.data);
    const inst_data = zir_datas[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.StructInit, inst_data.payload_index);
    const src = inst_data.src();

    const first_item = sema.code.extraData(Zir.Inst.StructInit.Item, extra.end).data;
    const first_field_type_data = zir_datas[first_item.field_type].pl_node;
    const first_field_type_extra = sema.code.extraData(Zir.Inst.FieldType, first_field_type_data.payload_index).data;
    const unresolved_struct_type = try sema.resolveType(block, src, first_field_type_extra.container_type);
    const resolved_ty = try sema.resolveTypeFields(block, src, unresolved_struct_type);

    if (resolved_ty.castTag(.@"struct")) |struct_payload| {
        const struct_obj = struct_payload.data;

        // Maps field index to field_type index of where it was already initialized.
        // For making sure all fields are accounted for and no fields are duplicated.
        const found_fields = try gpa.alloc(Zir.Inst.Index, struct_obj.fields.count());
        defer gpa.free(found_fields);
        mem.set(Zir.Inst.Index, found_fields, 0);

        // The init values to use for the struct instance.
        const field_inits = try gpa.alloc(Air.Inst.Ref, struct_obj.fields.count());
        defer gpa.free(field_inits);

        var field_i: u32 = 0;
        var extra_index = extra.end;

        while (field_i < extra.data.fields_len) : (field_i += 1) {
            const item = sema.code.extraData(Zir.Inst.StructInit.Item, extra_index);
            extra_index = item.end;

            const field_type_data = zir_datas[item.data.field_type].pl_node;
            const field_src: LazySrcLoc = .{ .node_offset_back2tok = field_type_data.src_node };
            const field_type_extra = sema.code.extraData(Zir.Inst.FieldType, field_type_data.payload_index).data;
            const field_name = sema.code.nullTerminatedString(field_type_extra.name_start);
            const field_index = struct_obj.fields.getIndex(field_name) orelse
                return sema.failWithBadStructFieldAccess(block, struct_obj, field_src, field_name);
            if (found_fields[field_index] != 0) {
                const other_field_type = found_fields[field_index];
                const other_field_type_data = zir_datas[other_field_type].pl_node;
                const other_field_src: LazySrcLoc = .{ .node_offset_back2tok = other_field_type_data.src_node };
                const msg = msg: {
                    const msg = try sema.errMsg(block, field_src, "duplicate field", .{});
                    errdefer msg.destroy(gpa);
                    try sema.errNote(block, other_field_src, msg, "other field here", .{});
                    break :msg msg;
                };
                return sema.failWithOwnedErrorMsg(msg);
            }
            found_fields[field_index] = item.data.field_type;
            field_inits[field_index] = sema.resolveInst(item.data.init);
        }

        var root_msg: ?*Module.ErrorMsg = null;

        for (found_fields) |field_type_inst, i| {
            if (field_type_inst != 0) continue;

            // Check if the field has a default init.
            const field = struct_obj.fields.values()[i];
            if (field.default_val.tag() == .unreachable_value) {
                const field_name = struct_obj.fields.keys()[i];
                const template = "missing struct field: {s}";
                const args = .{field_name};
                if (root_msg) |msg| {
                    try sema.errNote(block, src, msg, template, args);
                } else {
                    root_msg = try sema.errMsg(block, src, template, args);
                }
            } else {
                field_inits[i] = try sema.addConstant(field.ty, field.default_val);
            }
        }
        if (root_msg) |msg| {
            const fqn = try struct_obj.getFullyQualifiedName(gpa);
            defer gpa.free(fqn);
            try sema.mod.errNoteNonLazy(
                struct_obj.srcLoc(),
                msg,
                "struct '{s}' declared here",
                .{fqn},
            );
            return sema.failWithOwnedErrorMsg(msg);
        }

        if (is_ref) {
            return sema.fail(block, src, "TODO: Sema.zirStructInit is_ref=true", .{});
        }

        const is_comptime = for (field_inits) |field_init| {
            if (!(try sema.isComptimeKnown(block, src, field_init))) {
                break false;
            }
        } else true;

        if (is_comptime) {
            const values = try sema.arena.alloc(Value, field_inits.len);
            for (field_inits) |field_init, i| {
                values[i] = (sema.resolveMaybeUndefVal(block, src, field_init) catch unreachable).?;
            }
            return sema.addConstant(resolved_ty, try Value.Tag.@"struct".create(sema.arena, values));
        }

        return sema.fail(block, src, "TODO: Sema.zirStructInit for runtime-known struct values", .{});
    } else if (resolved_ty.cast(Type.Payload.Union)) |union_payload| {
        const union_obj = union_payload.data;

        if (extra.data.fields_len != 1) {
            return sema.fail(block, src, "union initialization expects exactly one field", .{});
        }

        const item = sema.code.extraData(Zir.Inst.StructInit.Item, extra.end);

        const field_type_data = zir_datas[item.data.field_type].pl_node;
        const field_src: LazySrcLoc = .{ .node_offset_back2tok = field_type_data.src_node };
        const field_type_extra = sema.code.extraData(Zir.Inst.FieldType, field_type_data.payload_index).data;
        const field_name = sema.code.nullTerminatedString(field_type_extra.name_start);
        const field_index_usize = union_obj.fields.getIndex(field_name) orelse
            return sema.failWithBadUnionFieldAccess(block, union_obj, field_src, field_name);
        const field_index = @intCast(u32, field_index_usize);

        if (is_ref) {
            return sema.fail(block, src, "TODO: Sema.zirStructInit is_ref=true union", .{});
        }

        const init_inst = sema.resolveInst(item.data.init);
        if (try sema.resolveMaybeUndefVal(block, field_src, init_inst)) |val| {
            const tag_val = try Value.Tag.enum_field_index.create(sema.arena, field_index);
            return sema.addConstant(
                resolved_ty,
                try Value.Tag.@"union".create(sema.arena, .{ .tag = tag_val, .val = val }),
            );
        }
        return sema.fail(block, src, "TODO: Sema.zirStructInit for runtime-known union values", .{});
    }
    unreachable;
}

fn zirStructInitAnon(sema: *Sema, block: *Block, inst: Zir.Inst.Index, is_ref: bool) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();

    _ = is_ref;
    return sema.fail(block, src, "TODO: Sema.zirStructInitAnon", .{});
}

fn zirArrayInit(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_ref: bool,
) CompileError!Air.Inst.Ref {
    const gpa = sema.gpa;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();

    const extra = sema.code.extraData(Zir.Inst.MultiOp, inst_data.payload_index);
    const args = sema.code.refSlice(extra.end, extra.data.operands_len);
    assert(args.len != 0);

    const resolved_args = try gpa.alloc(Air.Inst.Ref, args.len);
    defer gpa.free(resolved_args);

    for (args) |arg, i| resolved_args[i] = sema.resolveInst(arg);

    const elem_ty = sema.typeOf(resolved_args[0]);

    const array_ty = try Type.Tag.array.create(sema.arena, .{
        .len = resolved_args.len,
        .elem_type = elem_ty,
    });

    const opt_runtime_src: ?LazySrcLoc = for (resolved_args) |arg| {
        const arg_src = src; // TODO better source location
        const comptime_known = try sema.isComptimeKnown(block, arg_src, arg);
        if (!comptime_known) break arg_src;
    } else null;

    const runtime_src = opt_runtime_src orelse {
        var anon_decl = try block.startAnonDecl();
        defer anon_decl.deinit();

        const elem_vals = try anon_decl.arena().alloc(Value, resolved_args.len);
        for (resolved_args) |arg, i| {
            // We checked that all args are comptime above.
            const arg_val = (sema.resolveMaybeUndefVal(block, src, arg) catch unreachable).?;
            elem_vals[i] = try arg_val.copy(anon_decl.arena());
        }

        const val = try Value.Tag.array.create(anon_decl.arena(), elem_vals);
        const decl = try anon_decl.finish(try array_ty.copy(anon_decl.arena()), val);
        if (is_ref) {
            return sema.analyzeDeclRef(decl);
        } else {
            return sema.analyzeDeclVal(block, .unneeded, decl);
        }
    };

    try sema.requireRuntimeBlock(block, runtime_src);
    try sema.resolveTypeLayout(block, src, elem_ty);

    const alloc_ty = try Type.ptr(sema.arena, .{
        .pointee_type = array_ty,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .local),
    });
    const alloc = try block.addTy(.alloc, alloc_ty);

    for (resolved_args) |arg, i| {
        const index = try sema.addIntUnsigned(Type.initTag(.u64), i);
        const elem_ptr = try block.addBinOp(.ptr_elem_ptr, alloc, index);
        _ = try block.addBinOp(.store, elem_ptr, arg);
    }
    if (is_ref) {
        return alloc;
    } else {
        return sema.analyzeLoad(block, .unneeded, alloc, .unneeded);
    }
}

fn zirArrayInitAnon(sema: *Sema, block: *Block, inst: Zir.Inst.Index, is_ref: bool) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();

    _ = is_ref;
    return sema.fail(block, src, "TODO: Sema.zirArrayInitAnon", .{});
}

fn zirFieldTypeRef(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirFieldTypeRef", .{});
}

fn zirFieldType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.FieldType, inst_data.payload_index).data;
    const src = inst_data.src();
    const field_name = sema.code.nullTerminatedString(extra.name_start);
    const unresolved_ty = try sema.resolveType(block, src, extra.container_type);
    const resolved_ty = try sema.resolveTypeFields(block, src, unresolved_ty);
    switch (resolved_ty.zigTypeTag()) {
        .Struct => {
            const struct_obj = resolved_ty.castTag(.@"struct").?.data;
            const field = struct_obj.fields.get(field_name) orelse
                return sema.failWithBadStructFieldAccess(block, struct_obj, src, field_name);
            return sema.addType(field.ty);
        },
        .Union => {
            const union_obj = resolved_ty.cast(Type.Payload.Union).?.data;
            const field = union_obj.fields.get(field_name) orelse
                return sema.failWithBadUnionFieldAccess(block, union_obj, src, field_name);
            return sema.addType(field.ty);
        },
        else => return sema.fail(block, src, "expected struct or union; found '{}'", .{
            resolved_ty,
        }),
    }
}

fn zirErrorReturnTrace(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.fail(block, src, "TODO: Sema.zirErrorReturnTrace", .{});
}

fn zirFrame(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.fail(block, src, "TODO: Sema.zirFrame", .{});
}

fn zirFrameAddress(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const src: LazySrcLoc = .{ .node_offset = @bitCast(i32, extended.operand) };
    return sema.fail(block, src, "TODO: Sema.zirFrameAddress", .{});
}

fn zirAlignOf(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ty = try sema.resolveType(block, operand_src, inst_data.operand);
    const resolved_ty = try sema.resolveTypeFields(block, operand_src, ty);
    try sema.resolveTypeLayout(block, operand_src, resolved_ty);
    const target = sema.mod.getTarget();
    const abi_align = resolved_ty.abiAlignment(target);
    return sema.addIntUnsigned(Type.comptime_int, abi_align);
}

fn zirBoolToInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand = sema.resolveInst(inst_data.operand);
    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        if (val.isUndef()) return sema.addConstUndef(Type.initTag(.u1));
        const bool_ints = [2]Air.Inst.Ref{ .zero, .one };
        return bool_ints[@boolToInt(val.toBool())];
    }
    return block.addUnOp(.bool_to_int, operand);
}

fn zirErrorName(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirErrorName", .{});
}

fn zirUnaryMath(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirUnaryMath", .{});
}

fn zirTagName(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirTagName", .{});
}

fn zirReify(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const type_info_ty = try sema.resolveBuiltinTypeFields(block, src, "TypeInfo");
    const uncasted_operand = sema.resolveInst(inst_data.operand);
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const type_info = try sema.coerce(block, type_info_ty, uncasted_operand, operand_src);
    const val = try sema.resolveConstValue(block, operand_src, type_info);
    const union_val = val.cast(Value.Payload.Union).?.data;
    const tag_ty = type_info_ty.unionTagType().?;
    const tag_index = tag_ty.enumTagFieldIndex(union_val.tag).?;
    switch (@intToEnum(std.builtin.TypeId, tag_index)) {
        .Type => return Air.Inst.Ref.type_type,
        .Void => return Air.Inst.Ref.void_type,
        .Bool => return Air.Inst.Ref.bool_type,
        .NoReturn => return Air.Inst.Ref.noreturn_type,
        .ComptimeFloat => return Air.Inst.Ref.comptime_float_type,
        .ComptimeInt => return Air.Inst.Ref.comptime_int_type,
        .Undefined => return Air.Inst.Ref.undefined_type,
        .Null => return Air.Inst.Ref.null_type,
        .AnyFrame => return Air.Inst.Ref.anyframe_type,
        .EnumLiteral => return Air.Inst.Ref.enum_literal_type,
        .Int => {
            const struct_val = union_val.val.castTag(.@"struct").?.data;
            // TODO use reflection instead of magic numbers here
            const signedness_val = struct_val[0];
            const bits_val = struct_val[1];

            const signedness = signedness_val.toEnum(std.builtin.Signedness);
            const bits = @intCast(u16, bits_val.toUnsignedInt());
            const ty = switch (signedness) {
                .signed => try Type.Tag.int_signed.create(sema.arena, bits),
                .unsigned => try Type.Tag.int_unsigned.create(sema.arena, bits),
            };
            return sema.addType(ty);
        },
        .Vector => {
            const struct_val = union_val.val.castTag(.@"struct").?.data;
            // TODO use reflection instead of magic numbers here
            const len_val = struct_val[0];
            const child_val = struct_val[1];

            const len = len_val.toUnsignedInt();
            var buffer: Value.ToTypeBuffer = undefined;
            const child_ty = child_val.toType(&buffer);

            const ty = try Type.vector(sema.arena, len, child_ty);
            return sema.addType(ty);
        },
        .Float => return sema.fail(block, src, "TODO: Sema.zirReify for Float", .{}),
        .Pointer => return sema.fail(block, src, "TODO: Sema.zirReify for Pointer", .{}),
        .Array => return sema.fail(block, src, "TODO: Sema.zirReify for Array", .{}),
        .Struct => return sema.fail(block, src, "TODO: Sema.zirReify for Struct", .{}),
        .Optional => return sema.fail(block, src, "TODO: Sema.zirReify for Optional", .{}),
        .ErrorUnion => return sema.fail(block, src, "TODO: Sema.zirReify for ErrorUnion", .{}),
        .ErrorSet => return sema.fail(block, src, "TODO: Sema.zirReify for ErrorSet", .{}),
        .Enum => return sema.fail(block, src, "TODO: Sema.zirReify for Enum", .{}),
        .Union => return sema.fail(block, src, "TODO: Sema.zirReify for Union", .{}),
        .Fn => return sema.fail(block, src, "TODO: Sema.zirReify for Fn", .{}),
        .BoundFn => @panic("TODO delete BoundFn from the language"),
        .Opaque => return sema.fail(block, src, "TODO: Sema.zirReify for Opaque", .{}),
        .Frame => return sema.fail(block, src, "TODO: Sema.zirReify for Frame", .{}),
    }
}

fn zirTypeName(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirTypeName", .{});
}

fn zirFrameType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirFrameType", .{});
}

fn zirFrameSize(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirFrameSize", .{});
}

fn zirFloatToInt(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    // TODO don't forget the safety check!
    return sema.fail(block, src, "TODO: Sema.zirFloatToInt", .{});
}

fn zirIntToFloat(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const dest_ty = try sema.resolveType(block, ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);
    const operand_ty = sema.typeOf(operand);

    try sema.checkFloatType(block, ty_src, dest_ty);
    _ = try sema.checkIntType(block, operand_src, operand_ty);

    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        const target = sema.mod.getTarget();
        const result_val = try val.intToFloat(sema.arena, dest_ty, target);
        return sema.addConstant(dest_ty, result_val);
    }

    try sema.requireRuntimeBlock(block, operand_src);
    return block.addTyOp(.int_to_float, dest_ty, operand);
}

fn zirIntToPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();

    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;

    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand_res = sema.resolveInst(extra.rhs);
    const operand_coerced = try sema.coerce(block, Type.usize, operand_res, operand_src);

    const type_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const type_res = try sema.resolveType(block, src, extra.lhs);
    if (type_res.zigTypeTag() != .Pointer)
        return sema.fail(block, type_src, "expected pointer, found '{}'", .{type_res});
    const ptr_align = type_res.ptrAlignment(sema.mod.getTarget());

    if (try sema.resolveDefinedValue(block, operand_src, operand_coerced)) |val| {
        const addr = val.toUnsignedInt();
        if (!type_res.isAllowzeroPtr() and addr == 0)
            return sema.fail(block, operand_src, "pointer type '{}' does not allow address zero", .{type_res});
        if (addr != 0 and addr % ptr_align != 0)
            return sema.fail(block, operand_src, "pointer type '{}' requires aligned address", .{type_res});

        const val_payload = try sema.arena.create(Value.Payload.U64);
        val_payload.* = .{
            .base = .{ .tag = .int_u64 },
            .data = addr,
        };
        return sema.addConstant(type_res, Value.initPayload(&val_payload.base));
    }

    try sema.requireRuntimeBlock(block, src);
    if (block.wantSafety()) {
        if (!type_res.isAllowzeroPtr()) {
            const is_non_zero = try block.addBinOp(.cmp_neq, operand_coerced, .zero_usize);
            try sema.addSafetyCheck(block, is_non_zero, .cast_to_null);
        }

        if (ptr_align > 1) {
            const val_payload = try sema.arena.create(Value.Payload.U64);
            val_payload.* = .{
                .base = .{ .tag = .int_u64 },
                .data = ptr_align - 1,
            };
            const align_minus_1 = try sema.addConstant(
                Type.usize,
                Value.initPayload(&val_payload.base),
            );
            const remainder = try block.addBinOp(.bit_and, operand_coerced, align_minus_1);
            const is_aligned = try block.addBinOp(.cmp_eq, remainder, .zero_usize);
            try sema.addSafetyCheck(block, is_aligned, .incorrect_alignment);
        }
    }
    return block.addBitCast(type_res, operand_coerced);
}

fn zirErrSetCast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirErrSetCast", .{});
}

fn zirPtrCast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);
    const operand_ty = sema.typeOf(operand);
    if (operand_ty.zigTypeTag() != .Pointer) {
        return sema.fail(block, operand_src, "expected pointer, found {s} type '{}'", .{
            @tagName(operand_ty.zigTypeTag()), operand_ty,
        });
    }
    if (dest_ty.zigTypeTag() != .Pointer) {
        return sema.fail(block, dest_ty_src, "expected pointer, found {s} type '{}'", .{
            @tagName(dest_ty.zigTypeTag()), dest_ty,
        });
    }
    return sema.coerceCompatiblePtrs(block, dest_ty, operand, operand_src);
}

fn zirTruncate(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = sema.resolveInst(extra.rhs);
    const operand_ty = sema.typeOf(operand);
    const dest_is_comptime_int = try sema.checkIntType(block, dest_ty_src, dest_ty);
    const src_is_comptime_int = try sema.checkIntType(block, operand_src, operand_ty);

    if (dest_is_comptime_int) {
        return sema.coerce(block, dest_ty, operand, operand_src);
    }

    const target = sema.mod.getTarget();
    const dest_info = dest_ty.intInfo(target);

    if (dest_info.bits == 0) {
        return sema.addConstant(dest_ty, Value.zero);
    }

    if (!src_is_comptime_int) {
        const src_info = operand_ty.intInfo(target);
        if (src_info.bits == 0) {
            return sema.addConstant(dest_ty, Value.zero);
        }

        if (src_info.signedness != dest_info.signedness) {
            return sema.fail(block, operand_src, "expected {s} integer type, found '{}'", .{
                @tagName(dest_info.signedness), operand_ty,
            });
        }
        if (src_info.bits > 0 and src_info.bits < dest_info.bits) {
            const msg = msg: {
                const msg = try sema.errMsg(
                    block,
                    src,
                    "destination type '{}' has more bits than source type '{}'",
                    .{ dest_ty, operand_ty },
                );
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(block, dest_ty_src, msg, "destination type has {d} bits", .{
                    dest_info.bits,
                });
                try sema.errNote(block, operand_src, msg, "source type has {d} bits", .{
                    src_info.bits,
                });
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
    }

    if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        if (val.isUndef()) return sema.addConstUndef(dest_ty);
        return sema.addConstant(dest_ty, try val.intTrunc(sema.arena, dest_info.signedness, dest_info.bits));
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.trunc, dest_ty, operand);
}

fn zirAlignCast(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const align_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ptr_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const dest_align = try sema.resolveAlign(block, align_src, extra.lhs);
    const ptr = sema.resolveInst(extra.rhs);
    const ptr_ty = sema.typeOf(ptr);

    // TODO in addition to pointers, this instruction is supposed to work for
    // pointer-like optionals and slices.
    try sema.checkPtrType(block, ptr_src, ptr_ty);

    // TODO compile error if the result pointer is comptime known and would have an
    // alignment that disagrees with the Decl's alignment.

    // TODO insert safety check that the alignment is correct

    const ptr_info = ptr_ty.ptrInfo().data;
    const dest_ty = try Type.ptr(sema.arena, .{
        .pointee_type = ptr_info.pointee_type,
        .@"align" = dest_align,
        .@"addrspace" = ptr_info.@"addrspace",
        .mutable = ptr_info.mutable,
        .@"allowzero" = ptr_info.@"allowzero",
        .@"volatile" = ptr_info.@"volatile",
        .size = ptr_info.size,
    });
    return sema.coerceCompatiblePtrs(block, dest_ty, ptr, ptr_src);
}

fn zirClz(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    // TODO implement support for vectors
    if (operand_ty.zigTypeTag() != .Int) {
        return sema.fail(block, ty_src, "expected integer type, found '{}'", .{
            operand_ty,
        });
    }
    const target = sema.mod.getTarget();
    const bits = operand_ty.intInfo(target).bits;
    if (bits == 0) return Air.Inst.Ref.zero;

    const result_ty = try Type.smallestUnsignedInt(sema.arena, bits);

    const runtime_src = if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        if (val.isUndef()) return sema.addConstUndef(result_ty);
        return sema.addIntUnsigned(result_ty, val.clz(operand_ty, target));
    } else operand_src;

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addTyOp(.clz, result_ty, operand);
}

fn zirCtz(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    // TODO implement support for vectors
    if (operand_ty.zigTypeTag() != .Int) {
        return sema.fail(block, ty_src, "expected integer type, found '{}'", .{
            operand_ty,
        });
    }
    const target = sema.mod.getTarget();
    const bits = operand_ty.intInfo(target).bits;
    if (bits == 0) return Air.Inst.Ref.zero;

    const result_ty = try Type.smallestUnsignedInt(sema.arena, bits);

    const runtime_src = if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        if (val.isUndef()) return sema.addConstUndef(result_ty);
        return sema.fail(block, operand_src, "TODO: implement comptime @ctz", .{});
    } else operand_src;

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addTyOp(.ctz, result_ty, operand);
}

fn zirPopCount(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand = sema.resolveInst(inst_data.operand);
    const operand_ty = sema.typeOf(operand);
    // TODO implement support for vectors
    if (operand_ty.zigTypeTag() != .Int) {
        return sema.fail(block, ty_src, "expected integer type, found '{}'", .{
            operand_ty,
        });
    }
    const target = sema.mod.getTarget();
    const bits = operand_ty.intInfo(target).bits;
    if (bits == 0) return Air.Inst.Ref.zero;

    const result_ty = try Type.smallestUnsignedInt(sema.arena, bits);

    const runtime_src = if (try sema.resolveMaybeUndefVal(block, operand_src, operand)) |val| {
        if (val.isUndef()) return sema.addConstUndef(result_ty);
        const result_val = try val.popCount(operand_ty, target, sema.arena);
        return sema.addConstant(result_ty, result_val);
    } else operand_src;

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addTyOp(.popcount, result_ty, operand);
}

fn zirByteSwap(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirByteSwap", .{});
}

fn zirBitReverse(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirBitReverse", .{});
}

fn zirShrExact(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirShrExact", .{});
}

fn zirBitOffsetOf(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirBitOffsetOf", .{});
}

fn zirOffsetOf(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirOffsetOf", .{});
}

/// Returns `true` if the type was a comptime_int.
fn checkIntType(sema: *Sema, block: *Block, src: LazySrcLoc, ty: Type) CompileError!bool {
    switch (ty.zigTypeTag()) {
        .ComptimeInt => return true,
        .Int => return false,
        else => return sema.fail(block, src, "expected integer type, found '{}'", .{ty}),
    }
}

fn checkPtrType(
    sema: *Sema,
    block: *Block,
    ty_src: LazySrcLoc,
    ty: Type,
) CompileError!void {
    switch (ty.zigTypeTag()) {
        .Pointer => {},
        else => return sema.fail(block, ty_src, "expected pointer type, found '{}'", .{ty}),
    }
}

fn checkFloatType(
    sema: *Sema,
    block: *Block,
    ty_src: LazySrcLoc,
    ty: Type,
) CompileError!void {
    switch (ty.zigTypeTag()) {
        .ComptimeFloat, .Float => {},
        else => return sema.fail(block, ty_src, "expected float type, found '{}'", .{ty}),
    }
}

fn checkNumericType(
    sema: *Sema,
    block: *Block,
    ty_src: LazySrcLoc,
    ty: Type,
) CompileError!void {
    switch (ty.zigTypeTag()) {
        .ComptimeFloat, .Float, .ComptimeInt, .Int => {},
        .Vector => switch (ty.childType().zigTypeTag()) {
            .ComptimeFloat, .Float, .ComptimeInt, .Int => {},
            else => |t| return sema.fail(block, ty_src, "expected number, found '{}'", .{t}),
        },
        else => return sema.fail(block, ty_src, "expected number, found '{}'", .{ty}),
    }
}

fn checkAtomicOperandType(
    sema: *Sema,
    block: *Block,
    ty_src: LazySrcLoc,
    ty: Type,
) CompileError!void {
    var buffer: Type.Payload.Bits = undefined;
    const target = sema.mod.getTarget();
    const max_atomic_bits = target_util.largestAtomicBits(target);
    const int_ty = switch (ty.zigTypeTag()) {
        .Int => ty,
        .Enum => ty.intTagType(&buffer),
        .Float => {
            const bit_count = ty.floatBits(target);
            if (bit_count > max_atomic_bits) {
                return sema.fail(
                    block,
                    ty_src,
                    "expected {d}-bit float type or smaller; found {d}-bit float type",
                    .{ max_atomic_bits, bit_count },
                );
            }
            return;
        },
        .Bool => return, // Will be treated as `u8`.
        else => {
            if (ty.isPtrAtRuntime()) return;

            return sema.fail(
                block,
                ty_src,
                "expected bool, integer, float, enum, or pointer type; found {}",
                .{ty},
            );
        },
    };
    const bit_count = int_ty.intInfo(target).bits;
    if (bit_count > max_atomic_bits) {
        return sema.fail(
            block,
            ty_src,
            "expected {d}-bit integer type or smaller; found {d}-bit integer type",
            .{ max_atomic_bits, bit_count },
        );
    }
}

fn checkPtrIsNotComptimeMutable(
    sema: *Sema,
    block: *Block,
    ptr_val: Value,
    ptr_src: LazySrcLoc,
    operand_src: LazySrcLoc,
) CompileError!void {
    _ = operand_src;
    if (ptr_val.isComptimeMutablePtr()) {
        return sema.fail(block, ptr_src, "cannot store runtime value in compile time variable", .{});
    }
}

fn checkComptimeVarStore(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    decl_ref_mut: Value.Payload.DeclRefMut.Data,
) CompileError!void {
    if (decl_ref_mut.runtime_index < block.runtime_index) {
        if (block.runtime_cond) |cond_src| {
            const msg = msg: {
                const msg = try sema.errMsg(block, src, "store to comptime variable depends on runtime condition", .{});
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(block, cond_src, msg, "runtime condition here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        if (block.runtime_loop) |loop_src| {
            const msg = msg: {
                const msg = try sema.errMsg(block, src, "cannot store to comptime variable in non-inline loop", .{});
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(block, loop_src, msg, "non-inline loop here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        unreachable;
    }
}

const SimdBinOp = struct {
    len: ?u64,
    /// Coerced to `result_ty`.
    lhs: Air.Inst.Ref,
    /// Coerced to `result_ty`.
    rhs: Air.Inst.Ref,
    lhs_val: ?Value,
    rhs_val: ?Value,
    /// Only different than `scalar_ty` when it is a vector operation.
    result_ty: Type,
    scalar_ty: Type,
};

fn checkSimdBinOp(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    uncasted_lhs: Air.Inst.Ref,
    uncasted_rhs: Air.Inst.Ref,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!SimdBinOp {
    const lhs_ty = sema.typeOf(uncasted_lhs);
    const rhs_ty = sema.typeOf(uncasted_rhs);
    const lhs_zig_ty_tag = try lhs_ty.zigTypeTagOrPoison();
    const rhs_zig_ty_tag = try rhs_ty.zigTypeTagOrPoison();

    var vec_len: ?u64 = null;
    if (lhs_zig_ty_tag == .Vector and rhs_zig_ty_tag == .Vector) {
        const lhs_len = lhs_ty.arrayLen();
        const rhs_len = rhs_ty.arrayLen();
        if (lhs_len != rhs_len) {
            const msg = msg: {
                const msg = try sema.errMsg(block, src, "vector length mismatch", .{});
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(block, lhs_src, msg, "length {d} here", .{lhs_len});
                try sema.errNote(block, rhs_src, msg, "length {d} here", .{rhs_len});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        vec_len = lhs_len;
    } else if (lhs_zig_ty_tag == .Vector or rhs_zig_ty_tag == .Vector) {
        const msg = msg: {
            const msg = try sema.errMsg(block, src, "mixed scalar and vector operands: {} and {}", .{
                lhs_ty, rhs_ty,
            });
            errdefer msg.destroy(sema.gpa);
            if (lhs_zig_ty_tag == .Vector) {
                try sema.errNote(block, lhs_src, msg, "vector here", .{});
                try sema.errNote(block, rhs_src, msg, "scalar here", .{});
            } else {
                try sema.errNote(block, lhs_src, msg, "scalar here", .{});
                try sema.errNote(block, rhs_src, msg, "vector here", .{});
            }
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }
    const result_ty = try sema.resolvePeerTypes(block, src, &.{ uncasted_lhs, uncasted_rhs }, .{
        .override = &[_]LazySrcLoc{ lhs_src, rhs_src },
    });
    const lhs = try sema.coerce(block, result_ty, uncasted_lhs, lhs_src);
    const rhs = try sema.coerce(block, result_ty, uncasted_rhs, rhs_src);

    return SimdBinOp{
        .len = vec_len,
        .lhs = lhs,
        .rhs = rhs,
        .lhs_val = try sema.resolveMaybeUndefVal(block, lhs_src, lhs),
        .rhs_val = try sema.resolveMaybeUndefVal(block, rhs_src, rhs),
        .result_ty = result_ty,
        .scalar_ty = result_ty.scalarType(),
    };
}

fn resolveExportOptions(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) CompileError!std.builtin.ExportOptions {
    const export_options_ty = try sema.getBuiltinType(block, src, "ExportOptions");
    const air_ref = sema.resolveInst(zir_ref);
    const coerced = try sema.coerce(block, export_options_ty, air_ref, src);
    const val = try sema.resolveConstValue(block, src, coerced);
    const fields = val.castTag(.@"struct").?.data;
    const struct_obj = export_options_ty.castTag(.@"struct").?.data;
    const name_index = struct_obj.fields.getIndex("name").?;
    const linkage_index = struct_obj.fields.getIndex("linkage").?;
    const section_index = struct_obj.fields.getIndex("section").?;
    if (!fields[section_index].isNull()) {
        return sema.fail(block, src, "TODO: implement exporting with linksection", .{});
    }
    const name_ty = Type.initTag(.const_slice_u8);
    return std.builtin.ExportOptions{
        .name = try fields[name_index].toAllocatedBytes(name_ty, sema.arena),
        .linkage = fields[linkage_index].toEnum(std.builtin.GlobalLinkage),
        .section = null, // TODO
    };
}

fn resolveAtomicOrder(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) CompileError!std.builtin.AtomicOrder {
    const atomic_order_ty = try sema.getBuiltinType(block, src, "AtomicOrder");
    const air_ref = sema.resolveInst(zir_ref);
    const coerced = try sema.coerce(block, atomic_order_ty, air_ref, src);
    const val = try sema.resolveConstValue(block, src, coerced);
    return val.toEnum(std.builtin.AtomicOrder);
}

fn resolveAtomicRmwOp(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
) CompileError!std.builtin.AtomicRmwOp {
    const atomic_rmw_op_ty = try sema.getBuiltinType(block, src, "AtomicRmwOp");
    const air_ref = sema.resolveInst(zir_ref);
    const coerced = try sema.coerce(block, atomic_rmw_op_ty, air_ref, src);
    const val = try sema.resolveConstValue(block, src, coerced);
    return val.toEnum(std.builtin.AtomicRmwOp);
}

fn zirCmpxchg(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    air_tag: Air.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Cmpxchg, inst_data.payload_index).data;
    const src = inst_data.src();
    // zig fmt: off
    const elem_ty_src      : LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ptr_src          : LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const expected_src     : LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    const new_value_src    : LazySrcLoc = .{ .node_offset_builtin_call_arg3 = inst_data.src_node };
    const success_order_src: LazySrcLoc = .{ .node_offset_builtin_call_arg4 = inst_data.src_node };
    const failure_order_src: LazySrcLoc = .{ .node_offset_builtin_call_arg5 = inst_data.src_node };
    // zig fmt: on
    const ptr = sema.resolveInst(extra.ptr);
    const ptr_ty = sema.typeOf(ptr);
    const elem_ty = ptr_ty.elemType();
    try sema.checkAtomicOperandType(block, elem_ty_src, elem_ty);
    if (elem_ty.zigTypeTag() == .Float) {
        return sema.fail(
            block,
            elem_ty_src,
            "expected bool, integer, enum, or pointer type; found '{}'",
            .{elem_ty},
        );
    }
    const expected_value = try sema.coerce(block, elem_ty, sema.resolveInst(extra.expected_value), expected_src);
    const new_value = try sema.coerce(block, elem_ty, sema.resolveInst(extra.new_value), new_value_src);
    const success_order = try sema.resolveAtomicOrder(block, success_order_src, extra.success_order);
    const failure_order = try sema.resolveAtomicOrder(block, failure_order_src, extra.failure_order);

    if (@enumToInt(success_order) < @enumToInt(std.builtin.AtomicOrder.Monotonic)) {
        return sema.fail(block, success_order_src, "success atomic ordering must be Monotonic or stricter", .{});
    }
    if (@enumToInt(failure_order) < @enumToInt(std.builtin.AtomicOrder.Monotonic)) {
        return sema.fail(block, failure_order_src, "failure atomic ordering must be Monotonic or stricter", .{});
    }
    if (@enumToInt(failure_order) > @enumToInt(success_order)) {
        return sema.fail(block, failure_order_src, "failure atomic ordering must be no stricter than success", .{});
    }
    if (failure_order == .Release or failure_order == .AcqRel) {
        return sema.fail(block, failure_order_src, "failure atomic ordering must not be Release or AcqRel", .{});
    }

    const result_ty = try Type.optional(sema.arena, elem_ty);

    // special case zero bit types
    if ((try sema.typeHasOnePossibleValue(block, elem_ty_src, elem_ty)) != null) {
        return sema.addConstant(result_ty, Value.@"null");
    }

    const runtime_src = if (try sema.resolveDefinedValue(block, ptr_src, ptr)) |ptr_val| rs: {
        if (try sema.resolveMaybeUndefVal(block, expected_src, expected_value)) |expected_val| {
            if (try sema.resolveMaybeUndefVal(block, new_value_src, new_value)) |new_val| {
                if (expected_val.isUndef() or new_val.isUndef()) {
                    // TODO: this should probably cause the memory stored at the pointer
                    // to become undef as well
                    return sema.addConstUndef(result_ty);
                }
                const stored_val = (try sema.pointerDeref(block, ptr_src, ptr_val, ptr_ty)) orelse break :rs ptr_src;
                const result_val = if (stored_val.eql(expected_val, elem_ty)) blk: {
                    try sema.storePtr(block, src, ptr, new_value);
                    break :blk Value.@"null";
                } else try Value.Tag.opt_payload.create(sema.arena, stored_val);

                return sema.addConstant(result_ty, result_val);
            } else break :rs new_value_src;
        } else break :rs expected_src;
    } else ptr_src;

    const flags: u32 = @as(u32, @enumToInt(success_order)) |
        (@as(u32, @enumToInt(failure_order)) << 3);

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addInst(.{
        .tag = air_tag,
        .data = .{ .ty_pl = .{
            .ty = try sema.addType(result_ty),
            .payload = try sema.addExtra(Air.Cmpxchg{
                .ptr = ptr,
                .expected_value = expected_value,
                .new_value = new_value,
                .flags = flags,
            }),
        } },
    });
}

fn zirSplat(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirSplat", .{});
}

fn zirReduce(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirReduce", .{});
}

fn zirShuffle(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirShuffle", .{});
}

fn zirSelect(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirSelect", .{});
}

fn zirAtomicLoad(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    // zig fmt: off
    const elem_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ptr_src    : LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const order_src  : LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    // zig fmt: on
    const ptr = sema.resolveInst(extra.lhs);
    const ptr_ty = sema.typeOf(ptr);
    const elem_ty = ptr_ty.elemType();
    try sema.checkAtomicOperandType(block, elem_ty_src, elem_ty);
    const order = try sema.resolveAtomicOrder(block, order_src, extra.rhs);

    switch (order) {
        .Release, .AcqRel => {
            return sema.fail(
                block,
                order_src,
                "@atomicLoad atomic ordering must not be Release or AcqRel",
                .{},
            );
        },
        else => {},
    }

    if (try sema.typeHasOnePossibleValue(block, elem_ty_src, elem_ty)) |val| {
        return sema.addConstant(elem_ty, val);
    }

    if (try sema.resolveDefinedValue(block, ptr_src, ptr)) |ptr_val| {
        if (try sema.pointerDeref(block, ptr_src, ptr_val, ptr_ty)) |elem_val| {
            return sema.addConstant(elem_ty, elem_val);
        }
    }

    try sema.requireRuntimeBlock(block, ptr_src);
    return block.addInst(.{
        .tag = .atomic_load,
        .data = .{ .atomic_load = .{
            .ptr = ptr,
            .order = order,
        } },
    });
}

fn zirAtomicRmw(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.AtomicRmw, inst_data.payload_index).data;
    const src = inst_data.src();
    // zig fmt: off
    const operand_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ptr_src       : LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const op_src        : LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    const operand_src   : LazySrcLoc = .{ .node_offset_builtin_call_arg3 = inst_data.src_node };
    const order_src     : LazySrcLoc = .{ .node_offset_builtin_call_arg4 = inst_data.src_node };
    // zig fmt: on
    const ptr = sema.resolveInst(extra.ptr);
    const ptr_ty = sema.typeOf(ptr);
    const operand_ty = ptr_ty.elemType();
    try sema.checkAtomicOperandType(block, operand_ty_src, operand_ty);
    const op = try sema.resolveAtomicRmwOp(block, op_src, extra.operation);

    switch (operand_ty.zigTypeTag()) {
        .Enum => if (op != .Xchg) {
            return sema.fail(block, op_src, "@atomicRmw with enum only allowed with .Xchg", .{});
        },
        .Bool => if (op != .Xchg) {
            return sema.fail(block, op_src, "@atomicRmw with bool only allowed with .Xchg", .{});
        },
        .Float => switch (op) {
            .Xchg, .Add, .Sub => {},
            else => return sema.fail(block, op_src, "@atomicRmw with float only allowed with .Xchg, .Add, and .Sub", .{}),
        },
        else => {},
    }
    const operand = try sema.coerce(block, operand_ty, sema.resolveInst(extra.operand), operand_src);
    const order = try sema.resolveAtomicOrder(block, order_src, extra.ordering);

    if (order == .Unordered) {
        return sema.fail(block, order_src, "@atomicRmw atomic ordering must not be Unordered", .{});
    }

    // special case zero bit types
    if (try sema.typeHasOnePossibleValue(block, operand_ty_src, operand_ty)) |val| {
        return sema.addConstant(operand_ty, val);
    }

    const runtime_src = if (try sema.resolveDefinedValue(block, ptr_src, ptr)) |ptr_val| rs: {
        const maybe_operand_val = try sema.resolveMaybeUndefVal(block, operand_src, operand);
        const operand_val = maybe_operand_val orelse {
            try sema.checkPtrIsNotComptimeMutable(block, ptr_val, ptr_src, operand_src);
            break :rs operand_src;
        };
        if (ptr_val.isComptimeMutablePtr()) {
            const target = sema.mod.getTarget();
            const stored_val = (try sema.pointerDeref(block, ptr_src, ptr_val, ptr_ty)) orelse break :rs ptr_src;
            const new_val = switch (op) {
                // zig fmt: off
                .Xchg => operand_val,
                .Add  => try stored_val.numberAddWrap(operand_val, operand_ty, sema.arena, target),
                .Sub  => try stored_val.numberSubWrap(operand_val, operand_ty, sema.arena, target),
                .And  => try stored_val.bitwiseAnd   (operand_val,             sema.arena),
                .Nand => try stored_val.bitwiseNand  (operand_val, operand_ty, sema.arena, target),
                .Or   => try stored_val.bitwiseOr    (operand_val,             sema.arena),
                .Xor  => try stored_val.bitwiseXor   (operand_val,             sema.arena),
                .Max  => try stored_val.numberMax    (operand_val),
                .Min  => try stored_val.numberMin    (operand_val),
                // zig fmt: on
            };
            try sema.storePtrVal(block, src, ptr_val, new_val, operand_ty);
            return sema.addConstant(operand_ty, stored_val);
        } else break :rs ptr_src;
    } else ptr_src;

    const flags: u32 = @as(u32, @enumToInt(order)) | (@as(u32, @enumToInt(op)) << 3);

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addInst(.{
        .tag = .atomic_rmw,
        .data = .{ .pl_op = .{
            .operand = ptr,
            .payload = try sema.addExtra(Air.AtomicRmw{
                .operand = operand,
                .flags = flags,
            }),
        } },
    });
}

fn zirAtomicStore(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.AtomicStore, inst_data.payload_index).data;
    const src = inst_data.src();
    // zig fmt: off
    const operand_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const ptr_src       : LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const operand_src   : LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    const order_src     : LazySrcLoc = .{ .node_offset_builtin_call_arg3 = inst_data.src_node };
    // zig fmt: on
    const ptr = sema.resolveInst(extra.ptr);
    const operand_ty = sema.typeOf(ptr).elemType();
    try sema.checkAtomicOperandType(block, operand_ty_src, operand_ty);
    const operand = try sema.coerce(block, operand_ty, sema.resolveInst(extra.operand), operand_src);
    const order = try sema.resolveAtomicOrder(block, order_src, extra.ordering);

    const air_tag: Air.Inst.Tag = switch (order) {
        .Acquire, .AcqRel => {
            return sema.fail(
                block,
                order_src,
                "@atomicStore atomic ordering must not be Acquire or AcqRel",
                .{},
            );
        },
        .Unordered => .atomic_store_unordered,
        .Monotonic => .atomic_store_monotonic,
        .Release => .atomic_store_release,
        .SeqCst => .atomic_store_seq_cst,
    };

    return sema.storePtr2(block, src, ptr, ptr_src, operand, operand_src, air_tag);
}

fn zirMulAdd(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirMulAdd", .{});
}

fn zirBuiltinCall(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirBuiltinCall", .{});
}

fn zirFieldPtrType(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirFieldPtrType", .{});
}

fn zirFieldParentPtr(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirFieldParentPtr", .{});
}

fn zirMinMax(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    air_tag: Air.Inst.Tag,
) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const lhs = sema.resolveInst(extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    try sema.checkNumericType(block, lhs_src, sema.typeOf(lhs));
    try sema.checkNumericType(block, rhs_src, sema.typeOf(rhs));
    const simd_op = try sema.checkSimdBinOp(block, src, lhs, rhs, lhs_src, rhs_src);

    // TODO @maximum(max_int, undefined) should return max_int

    const runtime_src = if (simd_op.lhs_val) |lhs_val| rs: {
        if (lhs_val.isUndef()) return sema.addConstUndef(simd_op.result_ty);

        const rhs_val = simd_op.rhs_val orelse break :rs rhs_src;

        if (rhs_val.isUndef()) return sema.addConstUndef(simd_op.result_ty);

        const opFunc = switch (air_tag) {
            .min => Value.numberMin,
            .max => Value.numberMax,
            else => unreachable,
        };
        const vec_len = simd_op.len orelse {
            const result_val = try opFunc(lhs_val, rhs_val);
            return sema.addConstant(simd_op.result_ty, result_val);
        };
        var lhs_buf: Value.ElemValueBuffer = undefined;
        var rhs_buf: Value.ElemValueBuffer = undefined;
        const elems = try sema.arena.alloc(Value, vec_len);
        for (elems) |*elem, i| {
            const lhs_elem_val = lhs_val.elemValueBuffer(i, &lhs_buf);
            const rhs_elem_val = rhs_val.elemValueBuffer(i, &rhs_buf);
            elem.* = try opFunc(lhs_elem_val, rhs_elem_val);
        }
        return sema.addConstant(
            simd_op.result_ty,
            try Value.Tag.array.create(sema.arena, elems),
        );
    } else rs: {
        if (simd_op.rhs_val) |rhs_val| {
            if (rhs_val.isUndef()) return sema.addConstUndef(simd_op.result_ty);
        }
        break :rs lhs_src;
    };

    try sema.requireRuntimeBlock(block, runtime_src);
    return block.addBinOp(air_tag, simd_op.lhs, simd_op.rhs);
}

fn zirMemcpy(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Memcpy, inst_data.payload_index).data;
    const src = inst_data.src();
    const dest_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const src_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const len_src: LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    const dest_ptr = sema.resolveInst(extra.dest);
    const dest_ptr_ty = sema.typeOf(dest_ptr);

    if (dest_ptr_ty.zigTypeTag() != .Pointer) {
        return sema.fail(block, dest_src, "expected pointer, found '{}'", .{dest_ptr_ty});
    }
    if (dest_ptr_ty.isConstPtr()) {
        return sema.fail(block, dest_src, "cannot store through const pointer '{}'", .{dest_ptr_ty});
    }

    const uncasted_src_ptr = sema.resolveInst(extra.source);
    const uncasted_src_ptr_ty = sema.typeOf(uncasted_src_ptr);
    if (uncasted_src_ptr_ty.zigTypeTag() != .Pointer) {
        return sema.fail(block, src_src, "expected pointer, found '{}'", .{
            uncasted_src_ptr_ty,
        });
    }
    const src_ptr_info = uncasted_src_ptr_ty.ptrInfo().data;
    const wanted_src_ptr_ty = try Type.ptr(sema.arena, .{
        .pointee_type = dest_ptr_ty.elemType2(),
        .@"align" = src_ptr_info.@"align",
        .@"addrspace" = src_ptr_info.@"addrspace",
        .mutable = false,
        .@"allowzero" = src_ptr_info.@"allowzero",
        .@"volatile" = src_ptr_info.@"volatile",
        .size = .Many,
    });
    const src_ptr = try sema.coerce(block, wanted_src_ptr_ty, uncasted_src_ptr, src_src);
    const len = try sema.coerce(block, Type.usize, sema.resolveInst(extra.byte_count), len_src);

    const maybe_dest_ptr_val = try sema.resolveDefinedValue(block, dest_src, dest_ptr);
    const maybe_src_ptr_val = try sema.resolveDefinedValue(block, src_src, src_ptr);
    const maybe_len_val = try sema.resolveDefinedValue(block, len_src, len);

    const runtime_src = if (maybe_dest_ptr_val) |dest_ptr_val| rs: {
        if (maybe_src_ptr_val) |src_ptr_val| {
            if (maybe_len_val) |len_val| {
                _ = dest_ptr_val;
                _ = src_ptr_val;
                _ = len_val;
                return sema.fail(block, src, "TODO: Sema.zirMemcpy at comptime", .{});
            } else break :rs len_src;
        } else break :rs src_src;
    } else dest_src;

    try sema.requireRuntimeBlock(block, runtime_src);
    _ = try block.addInst(.{
        .tag = .memcpy,
        .data = .{ .pl_op = .{
            .operand = dest_ptr,
            .payload = try sema.addExtra(Air.Bin{
                .lhs = src_ptr,
                .rhs = len,
            }),
        } },
    });
}

fn zirMemset(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(Zir.Inst.Memset, inst_data.payload_index).data;
    const src = inst_data.src();
    const dest_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const value_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const len_src: LazySrcLoc = .{ .node_offset_builtin_call_arg2 = inst_data.src_node };
    const dest_ptr = sema.resolveInst(extra.dest);
    const dest_ptr_ty = sema.typeOf(dest_ptr);
    if (dest_ptr_ty.zigTypeTag() != .Pointer) {
        return sema.fail(block, dest_src, "expected pointer, found '{}'", .{dest_ptr_ty});
    }
    if (dest_ptr_ty.isConstPtr()) {
        return sema.fail(block, dest_src, "cannot store through const pointer '{}'", .{dest_ptr_ty});
    }
    const elem_ty = dest_ptr_ty.elemType2();
    const value = try sema.coerce(block, elem_ty, sema.resolveInst(extra.byte), value_src);
    const len = try sema.coerce(block, Type.usize, sema.resolveInst(extra.byte_count), len_src);

    const maybe_dest_ptr_val = try sema.resolveDefinedValue(block, dest_src, dest_ptr);
    const maybe_len_val = try sema.resolveDefinedValue(block, len_src, len);

    const runtime_src = if (maybe_dest_ptr_val) |ptr_val| rs: {
        if (maybe_len_val) |len_val| {
            if (try sema.resolveMaybeUndefVal(block, value_src, value)) |val| {
                _ = ptr_val;
                _ = len_val;
                _ = val;
                return sema.fail(block, src, "TODO: Sema.zirMemset at comptime", .{});
            } else break :rs value_src;
        } else break :rs len_src;
    } else dest_src;

    try sema.requireRuntimeBlock(block, runtime_src);
    _ = try block.addInst(.{
        .tag = .memset,
        .data = .{ .pl_op = .{
            .operand = dest_ptr,
            .payload = try sema.addExtra(Air.Bin{
                .lhs = value,
                .rhs = len,
            }),
        } },
    });
}

fn zirBuiltinAsyncCall(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirBuiltinAsyncCall", .{});
}

fn zirResume(sema: *Sema, block: *Block, inst: Zir.Inst.Index) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.fail(block, src, "TODO: Sema.zirResume", .{});
}

fn zirAwait(
    sema: *Sema,
    block: *Block,
    inst: Zir.Inst.Index,
    is_nosuspend: bool,
) CompileError!Air.Inst.Ref {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();

    _ = is_nosuspend;
    return sema.fail(block, src, "TODO: Sema.zirAwait", .{});
}

fn zirVarExtended(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.ExtendedVar, extended.operand);
    const src = sema.src;
    const ty_src: LazySrcLoc = src; // TODO add a LazySrcLoc that points at type
    const mut_src: LazySrcLoc = src; // TODO add a LazySrcLoc that points at mut token
    const init_src: LazySrcLoc = src; // TODO add a LazySrcLoc that points at init expr
    const small = @bitCast(Zir.Inst.ExtendedVar.Small, extended.small);

    var extra_index: usize = extra.end;

    const lib_name: ?[]const u8 = if (small.has_lib_name) blk: {
        const lib_name = sema.code.nullTerminatedString(sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk lib_name;
    } else null;

    // ZIR supports encoding this information but it is not used; the information
    // is encoded via the Decl entry.
    assert(!small.has_align);
    //const align_val: Value = if (small.has_align) blk: {
    //    const align_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
    //    extra_index += 1;
    //    const align_tv = try sema.resolveInstConst(block, align_src, align_ref);
    //    break :blk align_tv.val;
    //} else Value.@"null";

    const uncasted_init: Air.Inst.Ref = if (small.has_init) blk: {
        const init_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk sema.resolveInst(init_ref);
    } else .none;

    const have_ty = extra.data.var_type != .none;
    const var_ty = if (have_ty)
        try sema.resolveType(block, ty_src, extra.data.var_type)
    else
        sema.typeOf(uncasted_init);

    const init_val = if (uncasted_init != .none) blk: {
        const init = if (have_ty)
            try sema.coerce(block, var_ty, uncasted_init, init_src)
        else
            uncasted_init;

        break :blk (try sema.resolveMaybeUndefVal(block, init_src, init)) orelse
            return sema.failWithNeededComptime(block, init_src);
    } else Value.initTag(.unreachable_value);

    try sema.validateVarType(block, mut_src, var_ty, small.is_extern);

    if (lib_name != null) {
        // Look at the sema code for functions which has this logic, it just needs to
        // be extracted and shared by both var and func
        return sema.fail(block, src, "TODO: handle var with lib_name in Sema", .{});
    }

    const new_var = try sema.gpa.create(Module.Var);

    log.debug("created variable {*} owner_decl: {*} ({s})", .{
        new_var, sema.owner_decl, sema.owner_decl.name,
    });

    new_var.* = .{
        .owner_decl = sema.owner_decl,
        .init = init_val,
        .is_extern = small.is_extern,
        .is_mutable = true, // TODO get rid of this unused field
        .is_threadlocal = small.is_threadlocal,
    };
    const result = try sema.addConstant(
        var_ty,
        try Value.Tag.variable.create(sema.arena, new_var),
    );
    return result;
}

fn zirFuncExtended(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
    inst: Zir.Inst.Index,
) CompileError!Air.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const extra = sema.code.extraData(Zir.Inst.ExtendedFunc, extended.operand);
    const src: LazySrcLoc = .{ .node_offset = extra.data.src_node };
    const cc_src: LazySrcLoc = .{ .node_offset_fn_type_cc = extra.data.src_node };
    const align_src: LazySrcLoc = src; // TODO add a LazySrcLoc that points at align
    const small = @bitCast(Zir.Inst.ExtendedFunc.Small, extended.small);

    var extra_index: usize = extra.end;

    const lib_name: ?[]const u8 = if (small.has_lib_name) blk: {
        const lib_name = sema.code.nullTerminatedString(sema.code.extra[extra_index]);
        extra_index += 1;
        break :blk lib_name;
    } else null;

    const cc: std.builtin.CallingConvention = if (small.has_cc) blk: {
        const cc_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        const cc_tv = try sema.resolveInstConst(block, cc_src, cc_ref);
        break :blk cc_tv.val.toEnum(std.builtin.CallingConvention);
    } else .Unspecified;

    const align_val: Value = if (small.has_align) blk: {
        const align_ref = @intToEnum(Zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        const align_tv = try sema.resolveInstConst(block, align_src, align_ref);
        break :blk align_tv.val;
    } else Value.@"null";

    const ret_ty_body = sema.code.extra[extra_index..][0..extra.data.ret_body_len];
    extra_index += ret_ty_body.len;

    var body_inst: Zir.Inst.Index = 0;
    var src_locs: Zir.Inst.Func.SrcLocs = undefined;
    if (extra.data.body_len != 0) {
        body_inst = inst;
        extra_index += extra.data.body_len;
        src_locs = sema.code.extraData(Zir.Inst.Func.SrcLocs, extra_index).data;
    }

    const is_var_args = small.is_var_args;
    const is_inferred_error = small.is_inferred_error;
    const is_extern = small.is_extern;

    return sema.funcCommon(
        block,
        extra.data.src_node,
        body_inst,
        ret_ty_body,
        cc,
        align_val,
        is_var_args,
        is_inferred_error,
        is_extern,
        src_locs,
        lib_name,
    );
}

fn zirCUndef(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.UnNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };

    const name = try sema.resolveConstString(block, src, extra.operand);
    try block.c_import_buf.?.writer().print("#undefine {s}\n", .{name});
    return Air.Inst.Ref.void_value;
}

fn zirCInclude(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.UnNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };

    const name = try sema.resolveConstString(block, src, extra.operand);
    try block.c_import_buf.?.writer().print("#include <{s}>\n", .{name});
    return Air.Inst.Ref.void_value;
}

fn zirCDefine(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.BinNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };

    const name = try sema.resolveConstString(block, src, extra.lhs);
    const rhs = sema.resolveInst(extra.rhs);
    if (sema.typeOf(rhs).zigTypeTag() != .Void) {
        const value = try sema.resolveConstString(block, src, extra.rhs);
        try block.c_import_buf.?.writer().print("#define {s} {s}\n", .{ name, value });
    } else {
        try block.c_import_buf.?.writer().print("#define {s}\n", .{name});
    }
    return Air.Inst.Ref.void_value;
}

fn zirWasmMemorySize(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.UnNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };
    return sema.fail(block, src, "TODO: implement Sema.zirWasmMemorySize", .{});
}

fn zirWasmMemoryGrow(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.BinNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };
    return sema.fail(block, src, "TODO: implement Sema.zirWasmMemoryGrow", .{});
}

fn zirBuiltinExtern(
    sema: *Sema,
    block: *Block,
    extended: Zir.Inst.Extended.InstData,
) CompileError!Air.Inst.Ref {
    const extra = sema.code.extraData(Zir.Inst.BinNode, extended.operand).data;
    const src: LazySrcLoc = .{ .node_offset = extra.node };
    return sema.fail(block, src, "TODO: implement Sema.zirBuiltinExtern", .{});
}

fn requireFunctionBlock(sema: *Sema, block: *Block, src: LazySrcLoc) !void {
    if (sema.func == null) {
        return sema.fail(block, src, "instruction illegal outside function body", .{});
    }
}

fn requireRuntimeBlock(sema: *Sema, block: *Block, src: LazySrcLoc) !void {
    if (block.is_comptime) {
        return sema.failWithNeededComptime(block, src);
    }
    try sema.requireFunctionBlock(block, src);
}

/// Emit a compile error if type cannot be used for a runtime variable.
fn validateVarType(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    var_ty: Type,
    is_extern: bool,
) CompileError!void {
    var ty = var_ty;
    while (true) switch (ty.zigTypeTag()) {
        .Bool,
        .Int,
        .Float,
        .ErrorSet,
        .Enum,
        .Frame,
        .AnyFrame,
        .Void,
        => return,

        .BoundFn,
        .ComptimeFloat,
        .ComptimeInt,
        .EnumLiteral,
        .NoReturn,
        .Type,
        .Undefined,
        .Null,
        => break,

        .Pointer => {
            const elem_ty = ty.childType();
            if (elem_ty.zigTypeTag() == .Opaque) return;
            ty = elem_ty;
        },
        .Opaque => if (is_extern) return else break,

        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            const child_ty = ty.optionalChild(&buf);
            return validateVarType(sema, block, src, child_ty, is_extern);
        },
        .Array, .Vector => ty = ty.elemType(),

        .ErrorUnion => ty = ty.errorUnionPayload(),

        .Fn, .Struct, .Union => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            if (resolved_ty.requiresComptime()) {
                break;
            } else {
                return;
            }
        },
    } else unreachable; // TODO should not need else unreachable

    return sema.fail(block, src, "variable of type '{}' must be const or comptime", .{var_ty});
}

pub const PanicId = enum {
    unreach,
    unwrap_null,
    unwrap_errunion,
    cast_to_null,
    incorrect_alignment,
    invalid_error_code,
};

fn addSafetyCheck(
    sema: *Sema,
    parent_block: *Block,
    ok: Air.Inst.Ref,
    panic_id: PanicId,
) !void {
    const gpa = sema.gpa;

    var fail_block: Block = .{
        .parent = parent_block,
        .sema = sema,
        .src_decl = parent_block.src_decl,
        .namespace = parent_block.namespace,
        .wip_capture_scope = parent_block.wip_capture_scope,
        .instructions = .{},
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
    };

    defer fail_block.instructions.deinit(gpa);

    _ = try sema.safetyPanic(&fail_block, .unneeded, panic_id);

    try parent_block.instructions.ensureUnusedCapacity(gpa, 1);

    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        1 + // The main block only needs space for the cond_br.
        @typeInfo(Air.CondBr).Struct.fields.len +
        1 + // The ok branch of the cond_br only needs space for the br.
        fail_block.instructions.items.len);

    try sema.air_instructions.ensureUnusedCapacity(gpa, 3);
    const block_inst = @intCast(Air.Inst.Index, sema.air_instructions.len);
    const cond_br_inst = block_inst + 1;
    const br_inst = cond_br_inst + 1;
    sema.air_instructions.appendAssumeCapacity(.{
        .tag = .block,
        .data = .{ .ty_pl = .{
            .ty = .void_type,
            .payload = sema.addExtraAssumeCapacity(Air.Block{
                .body_len = 1,
            }),
        } },
    });
    sema.air_extra.appendAssumeCapacity(cond_br_inst);

    sema.air_instructions.appendAssumeCapacity(.{
        .tag = .cond_br,
        .data = .{ .pl_op = .{
            .operand = ok,
            .payload = sema.addExtraAssumeCapacity(Air.CondBr{
                .then_body_len = 1,
                .else_body_len = @intCast(u32, fail_block.instructions.items.len),
            }),
        } },
    });
    sema.air_extra.appendAssumeCapacity(br_inst);
    sema.air_extra.appendSliceAssumeCapacity(fail_block.instructions.items);

    sema.air_instructions.appendAssumeCapacity(.{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = block_inst,
            .operand = .void_value,
        } },
    });

    parent_block.instructions.appendAssumeCapacity(block_inst);
}

fn panicWithMsg(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    msg_inst: Air.Inst.Ref,
) !Zir.Inst.Index {
    const mod = sema.mod;
    const arena = sema.arena;

    const this_feature_is_implemented_in_the_backend =
        mod.comp.bin_file.options.object_format == .c or
        mod.comp.bin_file.options.use_llvm;
    if (!this_feature_is_implemented_in_the_backend) {
        // TODO implement this feature in all the backends and then delete this branch
        _ = try block.addNoOp(.breakpoint);
        _ = try block.addNoOp(.unreach);
        return always_noreturn;
    }
    const panic_fn = try sema.getBuiltin(block, src, "panic");
    const unresolved_stack_trace_ty = try sema.getBuiltinType(block, src, "StackTrace");
    const stack_trace_ty = try sema.resolveTypeFields(block, src, unresolved_stack_trace_ty);
    const ptr_stack_trace_ty = try Type.ptr(arena, .{
        .pointee_type = stack_trace_ty,
        .@"addrspace" = target_util.defaultAddressSpace(mod.getTarget(), .global_constant), // TODO might need a place that is more dynamic
    });
    const null_stack_trace = try sema.addConstant(
        try Type.optional(arena, ptr_stack_trace_ty),
        Value.@"null",
    );
    const args = try arena.create([2]Air.Inst.Ref);
    args.* = .{ msg_inst, null_stack_trace };
    _ = try sema.analyzeCall(block, panic_fn, src, src, .auto, false, args);
    return always_noreturn;
}

fn safetyPanic(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    panic_id: PanicId,
) CompileError!Zir.Inst.Index {
    const msg = switch (panic_id) {
        .unreach => "reached unreachable code",
        .unwrap_null => "attempt to use null value",
        .unwrap_errunion => "unreachable error occurred",
        .cast_to_null => "cast causes pointer to be null",
        .incorrect_alignment => "incorrect alignment",
        .invalid_error_code => "invalid error code",
    };

    const msg_inst = msg_inst: {
        // TODO instead of making a new decl for every panic in the entire compilation,
        // introduce the concept of a reference-counted decl for these
        var anon_decl = try block.startAnonDecl();
        defer anon_decl.deinit();
        break :msg_inst try sema.analyzeDeclRef(try anon_decl.finish(
            try Type.Tag.array_u8.create(anon_decl.arena(), msg.len),
            try Value.Tag.bytes.create(anon_decl.arena(), msg),
        ));
    };

    const casted_msg_inst = try sema.coerce(block, Type.initTag(.const_slice_u8), msg_inst, src);
    return sema.panicWithMsg(block, src, casted_msg_inst);
}

fn emitBackwardBranch(sema: *Sema, block: *Block, src: LazySrcLoc) !void {
    sema.branch_count += 1;
    if (sema.branch_count > sema.branch_quota) {
        // TODO show the "called from here" stack
        return sema.fail(block, src, "evaluation exceeded {d} backwards branches", .{sema.branch_quota});
    }
}

fn fieldVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    object: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    // When editing this function, note that there is corresponding logic to be edited
    // in `fieldPtr`. This function takes a value and returns a value.

    const arena = sema.arena;
    const object_src = src; // TODO better source location
    const object_ty = sema.typeOf(object);

    // Zig allows dereferencing a single pointer during field lookup. Note that
    // we don't actually need to generate the dereference some field lookups, like the
    // length of arrays and other comptime operations.
    const is_pointer_to = object_ty.isSinglePointer();

    const inner_ty = if (is_pointer_to)
        object_ty.childType()
    else
        object_ty;

    switch (inner_ty.zigTypeTag()) {
        .Array => {
            if (mem.eql(u8, field_name, "len")) {
                return sema.addConstant(
                    Type.initTag(.comptime_int),
                    try Value.Tag.int_u64.create(arena, inner_ty.arrayLen()),
                );
            } else {
                return sema.fail(
                    block,
                    field_name_src,
                    "no member named '{s}' in '{}'",
                    .{ field_name, object_ty },
                );
            }
        },
        .Pointer => if (inner_ty.isSlice()) {
            if (mem.eql(u8, field_name, "ptr")) {
                const slice = if (is_pointer_to)
                    try sema.analyzeLoad(block, src, object, object_src)
                else
                    object;
                return sema.analyzeSlicePtr(block, src, slice, inner_ty, object_src);
            } else if (mem.eql(u8, field_name, "len")) {
                const slice = if (is_pointer_to)
                    try sema.analyzeLoad(block, src, object, object_src)
                else
                    object;
                return sema.analyzeSliceLen(block, src, slice);
            } else {
                return sema.fail(
                    block,
                    field_name_src,
                    "no member named '{s}' in '{}'",
                    .{ field_name, object_ty },
                );
            }
        },
        .Type => {
            const dereffed_type = if (is_pointer_to)
                try sema.analyzeLoad(block, src, object, object_src)
            else
                object;

            const val = (try sema.resolveDefinedValue(block, object_src, dereffed_type)).?;
            var to_type_buffer: Value.ToTypeBuffer = undefined;
            const child_type = val.toType(&to_type_buffer);

            switch (child_type.zigTypeTag()) {
                .ErrorSet => {
                    const name: []const u8 = if (child_type.castTag(.error_set)) |payload| blk: {
                        const error_set = payload.data;
                        // TODO this is O(N). I'm putting off solving this until we solve inferred
                        // error sets at the same time.
                        const names = error_set.names_ptr[0..error_set.names_len];
                        for (names) |name| {
                            if (mem.eql(u8, field_name, name)) {
                                break :blk name;
                            }
                        }
                        return sema.fail(block, src, "no error named '{s}' in '{}'", .{
                            field_name, child_type,
                        });
                    } else (try sema.mod.getErrorValue(field_name)).key;

                    return sema.addConstant(
                        try child_type.copy(arena),
                        try Value.Tag.@"error".create(arena, .{ .name = name }),
                    );
                },
                .Union => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupVal(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    if (child_type.unionTagType()) |enum_ty| {
                        if (enum_ty.enumFieldIndex(field_name)) |field_index_usize| {
                            const field_index = @intCast(u32, field_index_usize);
                            return sema.addConstant(
                                enum_ty,
                                try Value.Tag.enum_field_index.create(sema.arena, field_index),
                            );
                        }
                    }
                    return sema.failWithBadMemberAccess(block, child_type, field_name_src, field_name);
                },
                .Enum => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupVal(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    const field_index_usize = child_type.enumFieldIndex(field_name) orelse
                        return sema.failWithBadMemberAccess(block, child_type, field_name_src, field_name);
                    const field_index = @intCast(u32, field_index_usize);
                    const enum_val = try Value.Tag.enum_field_index.create(arena, field_index);
                    return sema.addConstant(try child_type.copy(arena), enum_val);
                },
                .Struct, .Opaque => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupVal(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    // TODO add note: declared here
                    const kw_name = switch (child_type.zigTypeTag()) {
                        .Struct => "struct",
                        .Opaque => "opaque",
                        .Union => "union",
                        else => unreachable,
                    };
                    return sema.fail(block, src, "{s} '{}' has no member named '{s}'", .{
                        kw_name, child_type, field_name,
                    });
                },
                else => return sema.fail(block, src, "type '{}' has no members", .{child_type}),
            }
        },
        .Struct => if (is_pointer_to) {
            // Avoid loading the entire struct by fetching a pointer and loading that
            const field_ptr = try sema.structFieldPtr(block, src, object, field_name, field_name_src, inner_ty);
            return sema.analyzeLoad(block, src, field_ptr, object_src);
        } else {
            return sema.structFieldVal(block, src, object, field_name, field_name_src, inner_ty);
        },
        .Union => if (is_pointer_to) {
            // Avoid loading the entire union by fetching a pointer and loading that
            const field_ptr = try sema.unionFieldPtr(block, src, object, field_name, field_name_src, inner_ty);
            return sema.analyzeLoad(block, src, field_ptr, object_src);
        } else {
            return sema.unionFieldVal(block, src, object, field_name, field_name_src, inner_ty);
        },
        else => {},
    }
    return sema.fail(block, src, "type '{}' does not support field access", .{object_ty});
}

fn fieldPtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    object_ptr: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    // When editing this function, note that there is corresponding logic to be edited
    // in `fieldVal`. This function takes a pointer and returns a pointer.

    const object_ptr_src = src; // TODO better source location
    const object_ptr_ty = sema.typeOf(object_ptr);
    const object_ty = switch (object_ptr_ty.zigTypeTag()) {
        .Pointer => object_ptr_ty.elemType(),
        else => return sema.fail(block, object_ptr_src, "expected pointer, found '{}'", .{object_ptr_ty}),
    };

    // Zig allows dereferencing a single pointer during field lookup. Note that
    // we don't actually need to generate the dereference some field lookups, like the
    // length of arrays and other comptime operations.
    const is_pointer_to = object_ty.isSinglePointer();

    const inner_ty = if (is_pointer_to)
        object_ty.childType()
    else
        object_ty;

    switch (inner_ty.zigTypeTag()) {
        .Array => {
            if (mem.eql(u8, field_name, "len")) {
                var anon_decl = try block.startAnonDecl();
                defer anon_decl.deinit();
                return sema.analyzeDeclRef(try anon_decl.finish(
                    Type.initTag(.comptime_int),
                    try Value.Tag.int_u64.create(anon_decl.arena(), inner_ty.arrayLen()),
                ));
            } else {
                return sema.fail(
                    block,
                    field_name_src,
                    "no member named '{s}' in '{}'",
                    .{ field_name, object_ty },
                );
            }
        },
        .Pointer => if (inner_ty.isSlice()) {
            const inner_ptr = if (is_pointer_to)
                try sema.analyzeLoad(block, src, object_ptr, object_ptr_src)
            else
                object_ptr;

            if (mem.eql(u8, field_name, "ptr")) {
                const buf = try sema.arena.create(Type.SlicePtrFieldTypeBuffer);
                const slice_ptr_ty = inner_ty.slicePtrFieldType(buf);

                if (try sema.resolveDefinedValue(block, object_ptr_src, inner_ptr)) |val| {
                    var anon_decl = try block.startAnonDecl();
                    defer anon_decl.deinit();

                    return sema.analyzeDeclRef(try anon_decl.finish(
                        try slice_ptr_ty.copy(anon_decl.arena()),
                        try val.slicePtr().copy(anon_decl.arena()),
                    ));
                }
                try sema.requireRuntimeBlock(block, src);

                const result_ty = try Type.ptr(sema.arena, .{
                    .pointee_type = slice_ptr_ty,
                    .mutable = object_ptr_ty.ptrIsMutable(),
                    .@"addrspace" = object_ptr_ty.ptrAddressSpace(),
                });

                return block.addTyOp(.ptr_slice_ptr_ptr, result_ty, inner_ptr);
            } else if (mem.eql(u8, field_name, "len")) {
                if (try sema.resolveDefinedValue(block, object_ptr_src, inner_ptr)) |val| {
                    var anon_decl = try block.startAnonDecl();
                    defer anon_decl.deinit();

                    return sema.analyzeDeclRef(try anon_decl.finish(
                        Type.usize,
                        try Value.Tag.int_u64.create(anon_decl.arena(), val.sliceLen()),
                    ));
                }
                try sema.requireRuntimeBlock(block, src);

                const result_ty = try Type.ptr(sema.arena, .{
                    .pointee_type = Type.usize,
                    .mutable = object_ptr_ty.ptrIsMutable(),
                    .@"addrspace" = object_ptr_ty.ptrAddressSpace(),
                });

                return block.addTyOp(.ptr_slice_len_ptr, result_ty, inner_ptr);
            } else {
                return sema.fail(
                    block,
                    field_name_src,
                    "no member named '{s}' in '{}'",
                    .{ field_name, object_ty },
                );
            }
        },
        .Type => {
            _ = try sema.resolveConstValue(block, object_ptr_src, object_ptr);
            const result = try sema.analyzeLoad(block, src, object_ptr, object_ptr_src);
            const inner = if (is_pointer_to)
                try sema.analyzeLoad(block, src, result, object_ptr_src)
            else
                result;

            const val = (sema.resolveDefinedValue(block, src, inner) catch unreachable).?;
            var to_type_buffer: Value.ToTypeBuffer = undefined;
            const child_type = val.toType(&to_type_buffer);

            switch (child_type.zigTypeTag()) {
                .ErrorSet => {
                    // TODO resolve inferred error sets
                    const name: []const u8 = if (child_type.castTag(.error_set)) |payload| blk: {
                        const error_set = payload.data;
                        // TODO this is O(N). I'm putting off solving this until we solve inferred
                        // error sets at the same time.
                        const names = error_set.names_ptr[0..error_set.names_len];
                        for (names) |name| {
                            if (mem.eql(u8, field_name, name)) {
                                break :blk name;
                            }
                        }
                        return sema.fail(block, src, "no error named '{s}' in '{}'", .{
                            field_name, child_type,
                        });
                    } else (try sema.mod.getErrorValue(field_name)).key;

                    var anon_decl = try block.startAnonDecl();
                    defer anon_decl.deinit();
                    return sema.analyzeDeclRef(try anon_decl.finish(
                        try child_type.copy(anon_decl.arena()),
                        try Value.Tag.@"error".create(anon_decl.arena(), .{ .name = name }),
                    ));
                },
                .Union => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupRef(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    if (child_type.unionTagType()) |enum_ty| {
                        if (enum_ty.enumFieldIndex(field_name)) |field_index| {
                            const field_index_u32 = @intCast(u32, field_index);
                            var anon_decl = try block.startAnonDecl();
                            defer anon_decl.deinit();
                            return sema.analyzeDeclRef(try anon_decl.finish(
                                try enum_ty.copy(anon_decl.arena()),
                                try Value.Tag.enum_field_index.create(anon_decl.arena(), field_index_u32),
                            ));
                        }
                    }
                    return sema.failWithBadMemberAccess(block, child_type, field_name_src, field_name);
                },
                .Enum => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupRef(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    const field_index = child_type.enumFieldIndex(field_name) orelse {
                        return sema.failWithBadMemberAccess(block, child_type, field_name_src, field_name);
                    };
                    const field_index_u32 = @intCast(u32, field_index);
                    var anon_decl = try block.startAnonDecl();
                    defer anon_decl.deinit();
                    return sema.analyzeDeclRef(try anon_decl.finish(
                        try child_type.copy(anon_decl.arena()),
                        try Value.Tag.enum_field_index.create(anon_decl.arena(), field_index_u32),
                    ));
                },
                .Struct, .Opaque => {
                    if (child_type.getNamespace()) |namespace| {
                        if (try sema.namespaceLookupRef(block, src, namespace, field_name)) |inst| {
                            return inst;
                        }
                    }
                    return sema.failWithBadMemberAccess(block, child_type, field_name_src, field_name);
                },
                else => return sema.fail(block, src, "type '{}' has no members", .{child_type}),
            }
        },
        .Struct => {
            const inner_ptr = if (is_pointer_to)
                try sema.analyzeLoad(block, src, object_ptr, object_ptr_src)
            else
                object_ptr;
            return sema.structFieldPtr(block, src, inner_ptr, field_name, field_name_src, inner_ty);
        },
        .Union => {
            const inner_ptr = if (is_pointer_to)
                try sema.analyzeLoad(block, src, object_ptr, object_ptr_src)
            else
                object_ptr;
            return sema.unionFieldPtr(block, src, inner_ptr, field_name, field_name_src, inner_ty);
        },
        else => {},
    }
    return sema.fail(block, src, "type '{}' does not support field access (fieldPtr, {}.{s})", .{ object_ty, object_ptr_ty, field_name });
}

fn fieldCallBind(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    raw_ptr: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    // When editing this function, note that there is corresponding logic to be edited
    // in `fieldVal`. This function takes a pointer and returns a pointer.

    const raw_ptr_src = src; // TODO better source location
    const raw_ptr_ty = sema.typeOf(raw_ptr);
    const inner_ty = if (raw_ptr_ty.zigTypeTag() == .Pointer and raw_ptr_ty.ptrSize() == .One)
        raw_ptr_ty.childType()
    else
        return sema.fail(block, raw_ptr_src, "expected single pointer, found '{}'", .{raw_ptr_ty});

    // Optionally dereference a second pointer to get the concrete type.
    const is_double_ptr = inner_ty.zigTypeTag() == .Pointer and inner_ty.ptrSize() == .One;
    const concrete_ty = if (is_double_ptr) inner_ty.childType() else inner_ty;
    const ptr_ty = if (is_double_ptr) inner_ty else raw_ptr_ty;
    const object_ptr = if (is_double_ptr)
        try sema.analyzeLoad(block, src, raw_ptr, src)
    else
        raw_ptr;

    const arena = sema.arena;
    find_field: {
        switch (concrete_ty.zigTypeTag()) {
            .Struct => {
                const struct_ty = try sema.resolveTypeFields(block, src, concrete_ty);
                const struct_obj = struct_ty.castTag(.@"struct").?.data;

                const field_index_usize = struct_obj.fields.getIndex(field_name) orelse
                    break :find_field;
                const field_index = @intCast(u32, field_index_usize);
                const field = struct_obj.fields.values()[field_index];

                const ptr_field_ty = try Type.ptr(arena, .{
                    .pointee_type = field.ty,
                    .mutable = ptr_ty.ptrIsMutable(),
                    .@"addrspace" = ptr_ty.ptrAddressSpace(),
                });

                if (try sema.resolveDefinedValue(block, src, object_ptr)) |struct_ptr_val| {
                    const pointer = try sema.addConstant(
                        ptr_field_ty,
                        try Value.Tag.field_ptr.create(arena, .{
                            .container_ptr = struct_ptr_val,
                            .field_index = field_index,
                        }),
                    );
                    return sema.analyzeLoad(block, src, pointer, src);
                }

                try sema.requireRuntimeBlock(block, src);
                const ptr_inst = try block.addStructFieldPtr(object_ptr, field_index, ptr_field_ty);
                return sema.analyzeLoad(block, src, ptr_inst, src);
            },
            .Union => return sema.fail(block, src, "TODO implement field calls on unions", .{}),
            .Type => {
                const namespace = try sema.analyzeLoad(block, src, object_ptr, src);
                return sema.fieldVal(block, src, namespace, field_name, field_name_src);
            },
            else => {},
        }
    }

    // If we get here, we need to look for a decl in the struct type instead.
    switch (concrete_ty.zigTypeTag()) {
        .Struct, .Opaque, .Union, .Enum => {
            if (concrete_ty.getNamespace()) |namespace| {
                if (try sema.namespaceLookupRef(block, src, namespace, field_name)) |inst| {
                    const decl_val = try sema.analyzeLoad(block, src, inst, src);
                    const decl_type = sema.typeOf(decl_val);
                    if (decl_type.zigTypeTag() == .Fn and
                        decl_type.fnParamLen() >= 1)
                    {
                        const first_param_type = decl_type.fnParamType(0);
                        const first_param_tag = first_param_type.tag();
                        // zig fmt: off
                        if (first_param_tag == .var_args_param or
                            first_param_tag == .generic_poison or (
                                first_param_type.zigTypeTag() == .Pointer and
                                first_param_type.ptrSize() == .One and
                                first_param_type.childType().eql(concrete_ty)))
                        {
                            // zig fmt: on
                            // TODO: bound fn calls on rvalues should probably
                            // generate a by-value argument somehow.
                            const ty = Type.Tag.bound_fn.init();
                            const value = try Value.Tag.bound_fn.create(arena, .{
                                .func_inst = decl_val,
                                .arg0_inst = object_ptr,
                            });
                            return sema.addConstant(ty, value);
                        } else if (first_param_type.eql(concrete_ty)) {
                            var deref = try sema.analyzeLoad(block, src, object_ptr, src);
                            const ty = Type.Tag.bound_fn.init();
                            const value = try Value.Tag.bound_fn.create(arena, .{
                                .func_inst = decl_val,
                                .arg0_inst = deref,
                            });
                            return sema.addConstant(ty, value);
                        }
                    }
                }
            }
        },
        else => {},
    }

    return sema.fail(block, src, "type '{}' has no field or member function named '{s}'", .{ concrete_ty, field_name });
}

fn namespaceLookup(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    namespace: *Namespace,
    decl_name: []const u8,
) CompileError!?*Decl {
    const gpa = sema.gpa;
    if (try sema.lookupInNamespace(block, src, namespace, decl_name, true)) |decl| {
        if (!decl.is_pub and decl.getFileScope() != block.getFileScope()) {
            const msg = msg: {
                const msg = try sema.errMsg(block, src, "'{s}' is not marked 'pub'", .{
                    decl_name,
                });
                errdefer msg.destroy(gpa);
                try sema.mod.errNoteNonLazy(decl.srcLoc(), msg, "declared here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        }
        return decl;
    }
    return null;
}

fn namespaceLookupRef(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    namespace: *Namespace,
    decl_name: []const u8,
) CompileError!?Air.Inst.Ref {
    const decl = (try sema.namespaceLookup(block, src, namespace, decl_name)) orelse return null;
    return try sema.analyzeDeclRef(decl);
}

fn namespaceLookupVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    namespace: *Namespace,
    decl_name: []const u8,
) CompileError!?Air.Inst.Ref {
    const decl = (try sema.namespaceLookup(block, src, namespace, decl_name)) orelse return null;
    return try sema.analyzeDeclVal(block, src, decl);
}

fn structFieldPtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    struct_ptr: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
    unresolved_struct_ty: Type,
) CompileError!Air.Inst.Ref {
    const arena = sema.arena;
    assert(unresolved_struct_ty.zigTypeTag() == .Struct);

    const struct_ptr_ty = sema.typeOf(struct_ptr);
    const struct_ty = try sema.resolveTypeFields(block, src, unresolved_struct_ty);
    const struct_obj = struct_ty.castTag(.@"struct").?.data;

    const field_index_big = struct_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadStructFieldAccess(block, struct_obj, field_name_src, field_name);
    const field_index = @intCast(u32, field_index_big);
    const field = struct_obj.fields.values()[field_index];
    const ptr_field_ty = try Type.ptr(arena, .{
        .pointee_type = field.ty,
        .mutable = struct_ptr_ty.ptrIsMutable(),
        .@"addrspace" = struct_ptr_ty.ptrAddressSpace(),
    });

    if (try sema.resolveDefinedValue(block, src, struct_ptr)) |struct_ptr_val| {
        return sema.addConstant(
            ptr_field_ty,
            try Value.Tag.field_ptr.create(arena, .{
                .container_ptr = struct_ptr_val,
                .field_index = field_index,
            }),
        );
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addStructFieldPtr(struct_ptr, field_index, ptr_field_ty);
}

fn structFieldVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    struct_byval: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
    unresolved_struct_ty: Type,
) CompileError!Air.Inst.Ref {
    assert(unresolved_struct_ty.zigTypeTag() == .Struct);

    const struct_ty = try sema.resolveTypeFields(block, src, unresolved_struct_ty);
    const struct_obj = struct_ty.castTag(.@"struct").?.data;

    const field_index_usize = struct_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadStructFieldAccess(block, struct_obj, field_name_src, field_name);
    const field_index = @intCast(u32, field_index_usize);
    const field = struct_obj.fields.values()[field_index];

    if (try sema.resolveMaybeUndefVal(block, src, struct_byval)) |struct_val| {
        if (struct_val.isUndef()) return sema.addConstUndef(field.ty);

        const field_values = struct_val.castTag(.@"struct").?.data;
        return sema.addConstant(field.ty, field_values[field_index]);
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addStructFieldVal(struct_byval, field_index, field.ty);
}

fn unionFieldPtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    union_ptr: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
    unresolved_union_ty: Type,
) CompileError!Air.Inst.Ref {
    const arena = sema.arena;
    assert(unresolved_union_ty.zigTypeTag() == .Union);

    const union_ptr_ty = sema.typeOf(union_ptr);
    const union_ty = try sema.resolveTypeFields(block, src, unresolved_union_ty);
    const union_obj = union_ty.cast(Type.Payload.Union).?.data;

    const field_index_big = union_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadUnionFieldAccess(block, union_obj, field_name_src, field_name);
    const field_index = @intCast(u32, field_index_big);

    const field = union_obj.fields.values()[field_index];
    const ptr_field_ty = try Type.ptr(arena, .{
        .pointee_type = field.ty,
        .mutable = union_ptr_ty.ptrIsMutable(),
        .@"addrspace" = union_ptr_ty.ptrAddressSpace(),
    });

    if (try sema.resolveDefinedValue(block, src, union_ptr)) |union_ptr_val| {
        // TODO detect inactive union field and emit compile error
        return sema.addConstant(
            ptr_field_ty,
            try Value.Tag.field_ptr.create(arena, .{
                .container_ptr = union_ptr_val,
                .field_index = field_index,
            }),
        );
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addStructFieldPtr(union_ptr, field_index, ptr_field_ty);
}

fn unionFieldVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    union_byval: Air.Inst.Ref,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
    unresolved_union_ty: Type,
) CompileError!Air.Inst.Ref {
    assert(unresolved_union_ty.zigTypeTag() == .Union);

    const union_ty = try sema.resolveTypeFields(block, src, unresolved_union_ty);
    const union_obj = union_ty.cast(Type.Payload.Union).?.data;

    const field_index_usize = union_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadUnionFieldAccess(block, union_obj, field_name_src, field_name);
    const field_index = @intCast(u32, field_index_usize);
    const field = union_obj.fields.values()[field_index];

    if (try sema.resolveMaybeUndefVal(block, src, union_byval)) |union_val| {
        if (union_val.isUndef()) return sema.addConstUndef(field.ty);

        // TODO detect inactive union field and emit compile error
        const active_val = union_val.castTag(.@"union").?.data.val;
        return sema.addConstant(field.ty, active_val);
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addStructFieldVal(union_byval, field_index, field.ty);
}

fn elemPtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    array_ptr: Air.Inst.Ref,
    elem_index: Air.Inst.Ref,
    elem_index_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const array_ptr_src = src; // TODO better source location
    const array_ptr_ty = sema.typeOf(array_ptr);
    const array_ty = switch (array_ptr_ty.zigTypeTag()) {
        .Pointer => array_ptr_ty.elemType(),
        else => return sema.fail(block, array_ptr_src, "expected pointer, found '{}'", .{array_ptr_ty}),
    };
    if (!array_ty.isIndexable()) {
        return sema.fail(block, src, "array access of non-indexable type '{}'", .{array_ty});
    }

    switch (array_ty.zigTypeTag()) {
        .Pointer => {
            // In all below cases, we have to deref the ptr operand to get the actual array pointer.
            const array = try sema.analyzeLoad(block, array_ptr_src, array_ptr, array_ptr_src);
            const result_ty = try array_ty.elemPtrType(sema.arena);
            switch (array_ty.ptrSize()) {
                .Slice => {
                    const maybe_slice_val = try sema.resolveDefinedValue(block, array_ptr_src, array);
                    const maybe_index_val = try sema.resolveDefinedValue(block, elem_index_src, elem_index);
                    const runtime_src = if (maybe_slice_val) |slice_val| rs: {
                        const index_val = maybe_index_val orelse break :rs elem_index_src;
                        const index = @intCast(usize, index_val.toUnsignedInt());
                        const elem_ptr = try slice_val.elemPtr(sema.arena, index);
                        return sema.addConstant(result_ty, elem_ptr);
                    } else array_ptr_src;

                    try sema.requireRuntimeBlock(block, runtime_src);
                    return block.addSliceElemPtr(array, elem_index, result_ty);
                },
                .Many, .C => {
                    const maybe_ptr_val = try sema.resolveDefinedValue(block, array_ptr_src, array);
                    const maybe_index_val = try sema.resolveDefinedValue(block, elem_index_src, elem_index);

                    const runtime_src = rs: {
                        const ptr_val = maybe_ptr_val orelse break :rs array_ptr_src;
                        const index_val = maybe_index_val orelse break :rs elem_index_src;
                        const index = @intCast(usize, index_val.toUnsignedInt());
                        const elem_ptr = try ptr_val.elemPtr(sema.arena, index);
                        return sema.addConstant(result_ty, elem_ptr);
                    };

                    try sema.requireRuntimeBlock(block, runtime_src);
                    return block.addPtrElemPtr(array, elem_index, result_ty);
                },
                .One => {
                    assert(array_ty.childType().zigTypeTag() == .Array); // Guaranteed by isIndexable
                    return sema.elemPtrArray(block, array_ptr_src, array, elem_index, elem_index_src);
                },
            }
        },
        .Array => return sema.elemPtrArray(block, array_ptr_src, array_ptr, elem_index, elem_index_src),
        .Vector => return sema.fail(block, src, "TODO implement Sema for elemPtr for vector", .{}),
        else => unreachable,
    }
}

fn elemVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    array: Air.Inst.Ref,
    elem_index: Air.Inst.Ref,
    elem_index_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const array_src = src; // TODO better source location
    const array_ty = sema.typeOf(array);

    if (!array_ty.isIndexable()) {
        return sema.fail(block, src, "array access of non-indexable type '{}'", .{array_ty});
    }

    switch (array_ty.zigTypeTag()) {
        .Pointer => switch (array_ty.ptrSize()) {
            .Slice => {
                const maybe_slice_val = try sema.resolveDefinedValue(block, array_src, array);
                const maybe_index_val = try sema.resolveDefinedValue(block, elem_index_src, elem_index);
                const runtime_src = if (maybe_slice_val) |slice_val| rs: {
                    const index_val = maybe_index_val orelse break :rs elem_index_src;
                    const index = @intCast(usize, index_val.toUnsignedInt());
                    const elem_val = try slice_val.elemValue(sema.arena, index);
                    return sema.addConstant(array_ty.elemType2(), elem_val);
                } else array_src;

                try sema.requireRuntimeBlock(block, runtime_src);
                return block.addBinOp(.slice_elem_val, array, elem_index);
            },
            .Many, .C => {
                const maybe_ptr_val = try sema.resolveDefinedValue(block, array_src, array);
                const maybe_index_val = try sema.resolveDefinedValue(block, elem_index_src, elem_index);

                const runtime_src = rs: {
                    const ptr_val = maybe_ptr_val orelse break :rs array_src;
                    const index_val = maybe_index_val orelse break :rs elem_index_src;
                    const index = @intCast(usize, index_val.toUnsignedInt());
                    const maybe_array_val = try sema.pointerDeref(block, array_src, ptr_val, array_ty);
                    const array_val = maybe_array_val orelse break :rs array_src;
                    const elem_val = try array_val.elemValue(sema.arena, index);
                    return sema.addConstant(array_ty.elemType2(), elem_val);
                };

                try sema.requireRuntimeBlock(block, runtime_src);
                return block.addBinOp(.ptr_elem_val, array, elem_index);
            },
            .One => {
                assert(array_ty.childType().zigTypeTag() == .Array); // Guaranteed by isIndexable
                const elem_ptr = try sema.elemPtr(block, array_src, array, elem_index, elem_index_src);
                return sema.analyzeLoad(block, array_src, elem_ptr, elem_index_src);
            },
        },
        .Array => {
            if (try sema.resolveMaybeUndefVal(block, array_src, array)) |array_val| {
                const elem_ty = array_ty.childType();
                if (array_val.isUndef()) return sema.addConstUndef(elem_ty);
                const maybe_index_val = try sema.resolveDefinedValue(block, elem_index_src, elem_index);
                if (maybe_index_val) |index_val| {
                    const index = @intCast(usize, index_val.toUnsignedInt());
                    const elem_val = try array_val.elemValue(sema.arena, index);
                    return sema.addConstant(elem_ty, elem_val);
                }
            }
            try sema.requireRuntimeBlock(block, array_src);
            return block.addBinOp(.array_elem_val, array, elem_index);
        },
        .Vector => return sema.fail(block, array_src, "TODO implement Sema for elemVal for vector", .{}),
        else => unreachable,
    }
}

fn elemPtrArray(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    array_ptr: Air.Inst.Ref,
    elem_index: Air.Inst.Ref,
    elem_index_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const array_ptr_ty = sema.typeOf(array_ptr);
    const result_ty = try array_ptr_ty.elemPtrType(sema.arena);

    if (try sema.resolveDefinedValue(block, src, array_ptr)) |array_ptr_val| {
        if (try sema.resolveDefinedValue(block, elem_index_src, elem_index)) |index_val| {
            // Both array pointer and index are compile-time known.
            const index_u64 = index_val.toUnsignedInt();
            // @intCast here because it would have been impossible to construct a value that
            // required a larger index.
            const elem_ptr = try array_ptr_val.elemPtr(sema.arena, @intCast(usize, index_u64));
            return sema.addConstant(result_ty, elem_ptr);
        }
    }
    // TODO safety check for array bounds
    try sema.requireRuntimeBlock(block, src);
    return block.addPtrElemPtr(array_ptr, elem_index, result_ty);
}

fn coerce(
    sema: *Sema,
    block: *Block,
    dest_ty_unresolved: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    switch (dest_ty_unresolved.tag()) {
        .var_args_param => return sema.coerceVarArgParam(block, inst, inst_src),
        .generic_poison => return inst,
        else => {},
    }
    const dest_ty_src = inst_src; // TODO better source location
    const dest_ty = try sema.resolveTypeFields(block, dest_ty_src, dest_ty_unresolved);
    const inst_ty = try sema.resolveTypeFields(block, inst_src, sema.typeOf(inst));
    // If the types are the same, we can return the operand.
    if (dest_ty.eql(inst_ty))
        return inst;

    const arena = sema.arena;
    const target = sema.mod.getTarget();

    const in_memory_result = coerceInMemoryAllowed(dest_ty, inst_ty, false, target);
    if (in_memory_result == .ok) {
        if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
            // Keep the comptime Value representation; take the new type.
            return sema.addConstant(dest_ty, val);
        }
        try sema.requireRuntimeBlock(block, inst_src);
        return block.addBitCast(dest_ty, inst);
    }

    // undefined to anything
    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
        if (val.isUndef() or inst_ty.zigTypeTag() == .Undefined) {
            return sema.addConstant(dest_ty, val);
        }
    }
    assert(inst_ty.zigTypeTag() != .Undefined);

    // comptime known number to other number
    // TODO why is this a separate function? should just be flattened into the
    // switch expression below.
    if (try sema.coerceNum(block, dest_ty, inst, inst_src)) |some|
        return some;

    switch (dest_ty.zigTypeTag()) {
        .Optional => {
            // null to ?T
            if (inst_ty.zigTypeTag() == .Null) {
                return sema.addConstant(dest_ty, Value.@"null");
            }

            // T to ?T
            const child_type = try dest_ty.optionalChildAlloc(sema.arena);
            const intermediate = try sema.coerce(block, child_type, inst, inst_src);
            return sema.wrapOptional(block, dest_ty, intermediate, inst_src);
        },
        .Pointer => {
            const dest_info = dest_ty.ptrInfo().data;

            // Function body to function pointer.
            if (inst_ty.zigTypeTag() == .Fn) {
                const fn_val = try sema.resolveConstValue(block, inst_src, inst);
                const fn_decl = fn_val.castTag(.function).?.data.owner_decl;
                const inst_as_ptr = try sema.analyzeDeclRef(fn_decl);
                return sema.coerce(block, dest_ty, inst_as_ptr, inst_src);
            }

            // *T to *[1]T
            single_item: {
                if (dest_info.size != .One) break :single_item;
                if (!inst_ty.isSinglePointer()) break :single_item;
                const ptr_elem_ty = inst_ty.childType();
                const array_ty = dest_info.pointee_type;
                if (array_ty.zigTypeTag() != .Array) break :single_item;
                const array_elem_ty = array_ty.childType();
                const dest_is_mut = dest_info.mutable;
                if (inst_ty.isConstPtr() and dest_is_mut) break :single_item;
                if (inst_ty.isVolatilePtr() and !dest_info.@"volatile") break :single_item;
                if (inst_ty.ptrAddressSpace() != dest_info.@"addrspace") break :single_item;
                switch (coerceInMemoryAllowed(array_elem_ty, ptr_elem_ty, dest_is_mut, target)) {
                    .ok => {},
                    .no_match => break :single_item,
                }
                return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
            }

            // Coercions where the source is a single pointer to an array.
            src_array_ptr: {
                if (!inst_ty.isSinglePointer()) break :src_array_ptr;
                const array_ty = inst_ty.childType();
                if (array_ty.zigTypeTag() != .Array) break :src_array_ptr;
                const array_elem_type = array_ty.childType();
                const dest_is_mut = dest_info.mutable;
                if (inst_ty.isConstPtr() and dest_is_mut) break :src_array_ptr;
                if (inst_ty.isVolatilePtr() and !dest_info.@"volatile") break :src_array_ptr;
                if (inst_ty.ptrAddressSpace() != dest_info.@"addrspace") break :src_array_ptr;

                const dst_elem_type = dest_info.pointee_type;
                switch (coerceInMemoryAllowed(dst_elem_type, array_elem_type, dest_is_mut, target)) {
                    .ok => {},
                    .no_match => break :src_array_ptr,
                }

                switch (dest_info.size) {
                    .Slice => {
                        // *[N]T to []T
                        return sema.coerceArrayPtrToSlice(block, dest_ty, inst, inst_src);
                    },
                    .C => {
                        // *[N]T to [*c]T
                        return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
                    },
                    .Many => {
                        // *[N]T to [*]T
                        // *[N:s]T to [*:s]T
                        // *[N:s]T to [*]T
                        if (dest_info.sentinel) |dst_sentinel| {
                            if (array_ty.sentinel()) |src_sentinel| {
                                if (src_sentinel.eql(dst_sentinel, dst_elem_type)) {
                                    return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
                                }
                            }
                        } else {
                            return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
                        }
                    },
                    .One => {},
                }
            }

            // coercion from C pointer
            if (inst_ty.isCPtr()) src_c_ptr: {
                // In this case we must add a safety check because the C pointer
                // could be null.
                const src_elem_ty = inst_ty.childType();
                const dest_is_mut = dest_info.mutable;
                const dst_elem_type = dest_info.pointee_type;
                switch (coerceInMemoryAllowed(dst_elem_type, src_elem_ty, dest_is_mut, target)) {
                    .ok => {},
                    .no_match => break :src_c_ptr,
                }
                // TODO add safety check for null pointer
                return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
            }

            // coercion to C pointer
            if (dest_info.size == .C) {
                switch (inst_ty.zigTypeTag()) {
                    .Null => {
                        return sema.addConstant(dest_ty, Value.@"null");
                    },
                    .ComptimeInt => {
                        const addr = try sema.coerce(block, Type.usize, inst, inst_src);
                        return sema.coerceCompatiblePtrs(block, dest_ty, addr, inst_src);
                    },
                    .Int => {
                        const ptr_size_ty = switch (inst_ty.intInfo(target).signedness) {
                            .signed => Type.isize,
                            .unsigned => Type.usize,
                        };
                        const addr = try sema.coerce(block, ptr_size_ty, inst, inst_src);
                        return sema.coerceCompatiblePtrs(block, dest_ty, addr, inst_src);
                    },
                    else => {},
                }
            }

            // cast from *T and [*]T to *c_void
            // but don't do it if the source type is a double pointer
            if (dest_info.pointee_type.tag() == .c_void and inst_ty.zigTypeTag() == .Pointer and
                inst_ty.childType().zigTypeTag() != .Pointer)
            {
                return sema.coerceCompatiblePtrs(block, dest_ty, inst, inst_src);
            }
        },
        .Int => {
            // integer widening
            if (inst_ty.zigTypeTag() == .Int) {
                assert(!(try sema.isComptimeKnown(block, inst_src, inst))); // handled above

                const dst_info = dest_ty.intInfo(target);
                const src_info = inst_ty.intInfo(target);
                if ((src_info.signedness == dst_info.signedness and dst_info.bits >= src_info.bits) or
                    // small enough unsigned ints can get casted to large enough signed ints
                    (dst_info.signedness == .signed and dst_info.bits > src_info.bits))
                {
                    try sema.requireRuntimeBlock(block, inst_src);
                    return block.addTyOp(.intcast, dest_ty, inst);
                }
            }
        },
        .Float => {
            // float widening
            if (inst_ty.zigTypeTag() == .Float) {
                assert(!(try sema.isComptimeKnown(block, inst_src, inst))); // handled above

                const src_bits = inst_ty.floatBits(target);
                const dst_bits = dest_ty.floatBits(target);
                if (dst_bits >= src_bits) {
                    try sema.requireRuntimeBlock(block, inst_src);
                    return block.addTyOp(.fpext, dest_ty, inst);
                }
            }
        },
        .Enum => switch (inst_ty.zigTypeTag()) {
            .EnumLiteral => {
                // enum literal to enum
                const val = try sema.resolveConstValue(block, inst_src, inst);
                const bytes = val.castTag(.enum_literal).?.data;
                const field_index = dest_ty.enumFieldIndex(bytes) orelse {
                    const msg = msg: {
                        const msg = try sema.errMsg(
                            block,
                            inst_src,
                            "enum '{}' has no field named '{s}'",
                            .{ dest_ty, bytes },
                        );
                        errdefer msg.destroy(sema.gpa);
                        try sema.mod.errNoteNonLazy(
                            dest_ty.declSrcLoc(),
                            msg,
                            "enum declared here",
                            .{},
                        );
                        break :msg msg;
                    };
                    return sema.failWithOwnedErrorMsg(msg);
                };
                return sema.addConstant(
                    dest_ty,
                    try Value.Tag.enum_field_index.create(arena, @intCast(u32, field_index)),
                );
            },
            .Union => blk: {
                // union to its own tag type
                const union_tag_ty = inst_ty.unionTagType() orelse break :blk;
                if (union_tag_ty.eql(dest_ty)) {
                    return sema.unionToTag(block, inst_ty, inst, inst_src);
                }
            },
            else => {},
        },
        .ErrorUnion => {
            // T to E!T or E to E!T
            return sema.wrapErrorUnion(block, dest_ty, inst, inst_src);
        },
        .ErrorSet => switch (inst_ty.zigTypeTag()) {
            .ErrorSet => {
                // Coercion to `anyerror`. Note that this check can return false positives
                // in case the error sets did not get resolved.
                if (dest_ty.isAnyError()) {
                    return sema.coerceCompatibleErrorSets(block, inst, inst_src);
                }
                // If both are inferred error sets of functions, and
                // the dest includes the source function, the coercion is OK.
                // This check is important because it works without forcing a full resolution
                // of inferred error sets.
                if (inst_ty.castTag(.error_set_inferred)) |src_payload| {
                    if (dest_ty.castTag(.error_set_inferred)) |dst_payload| {
                        const src_func = src_payload.data.func;
                        const dst_func = dst_payload.data.func;

                        if (src_func == dst_func or dst_payload.data.functions.contains(src_func)) {
                            return sema.coerceCompatibleErrorSets(block, inst, inst_src);
                        }
                    }
                }
                // TODO full error set resolution and compare sets by names.
            },
            else => {},
        },
        .Union => switch (inst_ty.zigTypeTag()) {
            .Enum, .EnumLiteral => return sema.coerceEnumToUnion(block, dest_ty, dest_ty_src, inst, inst_src),
            else => {},
        },
        .Array => switch (inst_ty.zigTypeTag()) {
            .Vector => return sema.coerceVectorInMemory(block, dest_ty, dest_ty_src, inst, inst_src),
            else => {},
        },
        .Vector => switch (inst_ty.zigTypeTag()) {
            .Array => return sema.coerceVectorInMemory(block, dest_ty, dest_ty_src, inst, inst_src),
            else => {},
        },
        else => {},
    }

    return sema.fail(block, inst_src, "expected {}, found {}", .{ dest_ty, inst_ty });
}

const InMemoryCoercionResult = enum {
    ok,
    no_match,
};

/// If pointers have the same representation in runtime memory, a bitcast AIR instruction
/// may be used for the coercion.
/// * `const` attribute can be gained
/// * `volatile` attribute can be gained
/// * `allowzero` attribute can be gained (whether from explicit attribute, C pointer, or optional pointer) but only if !dest_is_mut
/// * alignment can be decreased
/// * bit offset attributes must match exactly
/// * `*`/`[*]` must match exactly, but `[*c]` matches either one
/// * sentinel-terminated pointers can coerce into `[*]`
/// TODO improve this function to report recursive compile errors like it does in stage1.
/// look at the function types_match_const_cast_only
fn coerceInMemoryAllowed(dest_ty: Type, src_ty: Type, dest_is_mut: bool, target: std.Target) InMemoryCoercionResult {
    if (dest_ty.eql(src_ty))
        return .ok;

    // Pointers / Pointer-like Optionals
    var dest_buf: Type.Payload.ElemType = undefined;
    var src_buf: Type.Payload.ElemType = undefined;
    if (dest_ty.ptrOrOptionalPtrTy(&dest_buf)) |dest_ptr_ty| {
        if (src_ty.ptrOrOptionalPtrTy(&src_buf)) |src_ptr_ty| {
            return coerceInMemoryAllowedPtrs(dest_ty, src_ty, dest_ptr_ty, src_ptr_ty, dest_is_mut, target);
        }
    }

    // Slices
    if (dest_ty.isSlice() and src_ty.isSlice()) {
        return coerceInMemoryAllowedPtrs(dest_ty, src_ty, dest_ty, src_ty, dest_is_mut, target);
    }

    // TODO: arrays
    // TODO: non-pointer-like optionals
    // TODO: error unions
    // TODO: error sets
    // TODO: functions
    // TODO: vectors

    return .no_match;
}

fn coerceInMemoryAllowedPtrs(
    dest_ty: Type,
    src_ty: Type,
    dest_ptr_ty: Type,
    src_ptr_ty: Type,
    dest_is_mut: bool,
    target: std.Target,
) InMemoryCoercionResult {
    const dest_info = dest_ptr_ty.ptrInfo().data;
    const src_info = src_ptr_ty.ptrInfo().data;

    const child = coerceInMemoryAllowed(dest_info.pointee_type, src_info.pointee_type, dest_info.mutable, target);
    if (child == .no_match) {
        return child;
    }

    if (dest_info.@"addrspace" != src_info.@"addrspace") {
        return .no_match;
    }

    const ok_sent = dest_info.sentinel == null or src_info.size == .C or
        (src_info.sentinel != null and
        dest_info.sentinel.?.eql(src_info.sentinel.?, dest_info.pointee_type));
    if (!ok_sent) {
        return .no_match;
    }

    const ok_ptr_size = src_info.size == dest_info.size or
        src_info.size == .C or dest_info.size == .C;
    if (!ok_ptr_size) {
        return .no_match;
    }

    const ok_cv_qualifiers =
        (src_info.mutable or !dest_info.mutable) and
        (!src_info.@"volatile" or dest_info.@"volatile");

    if (!ok_cv_qualifiers) {
        return .no_match;
    }

    const dest_allow_zero = dest_ty.ptrAllowsZero();
    const src_allow_zero = src_ty.ptrAllowsZero();

    const ok_allows_zero = (dest_allow_zero and
        (src_allow_zero or !dest_is_mut)) or
        (!dest_allow_zero and !src_allow_zero);
    if (!ok_allows_zero) {
        return .no_match;
    }

    if (src_info.host_size != dest_info.host_size or
        src_info.bit_offset != dest_info.bit_offset)
    {
        return .no_match;
    }

    // If both pointers have alignment 0, it means they both want ABI alignment.
    // In this case, if they share the same child type, no need to resolve
    // pointee type alignment. Otherwise both pointee types must have their alignment
    // resolved and we compare the alignment numerically.
    if (src_info.@"align" != 0 or dest_info.@"align" != 0 or
        !dest_info.pointee_type.eql(src_info.pointee_type))
    {
        const src_align = src_info.@"align";
        const dest_align = dest_info.@"align";

        if (dest_align > src_align) {
            return .no_match;
        }
    }

    return .ok;
}

fn coerceNum(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) CompileError!?Air.Inst.Ref {
    const val = (try sema.resolveDefinedValue(block, inst_src, inst)) orelse return null;
    const inst_ty = sema.typeOf(inst);
    const src_zig_tag = inst_ty.zigTypeTag();
    const dst_zig_tag = dest_ty.zigTypeTag();

    const target = sema.mod.getTarget();

    switch (dst_zig_tag) {
        .ComptimeInt, .Int => switch (src_zig_tag) {
            .Float, .ComptimeFloat => {
                if (val.floatHasFraction()) {
                    return sema.fail(block, inst_src, "fractional component prevents float value {} from coercion to type '{}'", .{ val, dest_ty });
                }
                return sema.fail(block, inst_src, "TODO float to int", .{});
            },
            .Int, .ComptimeInt => {
                if (!val.intFitsInType(dest_ty, target)) {
                    return sema.fail(block, inst_src, "type {} cannot represent integer value {}", .{ dest_ty, val });
                }
                return try sema.addConstant(dest_ty, val);
            },
            else => {},
        },
        .ComptimeFloat, .Float => switch (src_zig_tag) {
            .ComptimeFloat => {
                const result_val = try val.floatCast(sema.arena, dest_ty);
                return try sema.addConstant(dest_ty, result_val);
            },
            .Float => {
                const result_val = try val.floatCast(sema.arena, dest_ty);
                if (!val.eql(result_val, dest_ty)) {
                    return sema.fail(
                        block,
                        inst_src,
                        "type {} cannot represent float value {}",
                        .{ dest_ty, val },
                    );
                }
                return try sema.addConstant(dest_ty, result_val);
            },
            .Int, .ComptimeInt => {
                const result_val = try val.intToFloat(sema.arena, dest_ty, target);
                // TODO implement this compile error
                //const int_again_val = try result_val.floatToInt(sema.arena, inst_ty);
                //if (!int_again_val.eql(val, inst_ty)) {
                //    return sema.fail(
                //        block,
                //        inst_src,
                //        "type {} cannot represent integer value {}",
                //        .{ dest_ty, val },
                //    );
                //}
                return try sema.addConstant(dest_ty, result_val);
            },
            else => {},
        },
        else => {},
    }
    return null;
}

fn coerceVarArgParam(
    sema: *Sema,
    block: *Block,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    const inst_ty = sema.typeOf(inst);
    switch (inst_ty.zigTypeTag()) {
        .ComptimeInt, .ComptimeFloat => return sema.fail(block, inst_src, "integer and float literals in var args function must be casted", .{}),
        else => {},
    }
    // TODO implement more of this function.
    return inst;
}

// TODO migrate callsites to use storePtr2 instead.
fn storePtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr: Air.Inst.Ref,
    uncasted_operand: Air.Inst.Ref,
) CompileError!void {
    return sema.storePtr2(block, src, ptr, src, uncasted_operand, src, .store);
}

fn storePtr2(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr: Air.Inst.Ref,
    ptr_src: LazySrcLoc,
    uncasted_operand: Air.Inst.Ref,
    operand_src: LazySrcLoc,
    air_tag: Air.Inst.Tag,
) !void {
    const ptr_ty = sema.typeOf(ptr);
    if (ptr_ty.isConstPtr())
        return sema.fail(block, src, "cannot assign to constant", .{});

    const elem_ty = ptr_ty.childType();
    const operand = try sema.coerce(block, elem_ty, uncasted_operand, operand_src);
    if ((try sema.typeHasOnePossibleValue(block, src, elem_ty)) != null)
        return;

    const runtime_src = if (try sema.resolveDefinedValue(block, ptr_src, ptr)) |ptr_val| rs: {
        const maybe_operand_val = try sema.resolveMaybeUndefVal(block, operand_src, operand);
        const operand_val = maybe_operand_val orelse {
            try sema.checkPtrIsNotComptimeMutable(block, ptr_val, ptr_src, operand_src);
            break :rs operand_src;
        };
        if (ptr_val.isComptimeMutablePtr()) {
            try sema.storePtrVal(block, src, ptr_val, operand_val, elem_ty);
            return;
        } else break :rs ptr_src;
    } else ptr_src;

    // TODO handle if the element type requires comptime

    try sema.requireRuntimeBlock(block, runtime_src);
    try sema.resolveTypeLayout(block, src, elem_ty);
    _ = try block.addBinOp(air_tag, ptr, operand);
}

/// Call when you have Value objects rather than Air instructions, and you want to
/// assert the store must be done at comptime.
fn storePtrVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_val: Value,
    operand_val: Value,
    operand_ty: Type,
) !void {
    var kit = try beginComptimePtrMutation(sema, block, src, ptr_val);
    try sema.checkComptimeVarStore(block, src, kit.decl_ref_mut);

    const target = sema.mod.getTarget();
    const bitcasted_val = try operand_val.bitCast(operand_ty, kit.ty, target, sema.gpa, sema.arena);

    const arena = kit.beginArena(sema.gpa);
    defer kit.finishArena();

    kit.val.* = try bitcasted_val.copy(arena);
}

const ComptimePtrMutationKit = struct {
    decl_ref_mut: Value.Payload.DeclRefMut.Data,
    val: *Value,
    ty: Type,
    decl_arena: std.heap.ArenaAllocator = undefined,

    fn beginArena(self: *ComptimePtrMutationKit, gpa: *Allocator) *Allocator {
        self.decl_arena = self.decl_ref_mut.decl.value_arena.?.promote(gpa);
        return &self.decl_arena.allocator;
    }

    fn finishArena(self: *ComptimePtrMutationKit) void {
        self.decl_ref_mut.decl.value_arena.?.* = self.decl_arena.state;
        self.decl_arena = undefined;
    }
};

fn beginComptimePtrMutation(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_val: Value,
) CompileError!ComptimePtrMutationKit {
    switch (ptr_val.tag()) {
        .decl_ref_mut => {
            const decl_ref_mut = ptr_val.castTag(.decl_ref_mut).?.data;
            return ComptimePtrMutationKit{
                .decl_ref_mut = decl_ref_mut,
                .val = &decl_ref_mut.decl.val,
                .ty = decl_ref_mut.decl.ty,
            };
        },
        .elem_ptr => {
            const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
            var parent = try beginComptimePtrMutation(sema, block, src, elem_ptr.array_ptr);
            const elem_ty = parent.ty.childType();
            switch (parent.val.tag()) {
                .undef => {
                    // An array has been initialized to undefined at comptime and now we
                    // are for the first time setting an element. We must change the representation
                    // of the array from `undef` to `array`.
                    const arena = parent.beginArena(sema.gpa);
                    defer parent.finishArena();

                    const elems = try arena.alloc(Value, parent.ty.arrayLenIncludingSentinel());
                    mem.set(Value, elems, Value.undef);

                    parent.val.* = try Value.Tag.array.create(arena, elems);

                    return ComptimePtrMutationKit{
                        .decl_ref_mut = parent.decl_ref_mut,
                        .val = &elems[elem_ptr.index],
                        .ty = elem_ty,
                    };
                },
                .bytes => {
                    // An array is memory-optimized to store a slice of bytes, but we are about
                    // to modify an individual field and the representation has to change.
                    // If we wanted to avoid this, there would need to be special detection
                    // elsewhere to identify when writing a value to an array element that is stored
                    // using the `bytes` tag, and handle it without making a call to this function.
                    const arena = parent.beginArena(sema.gpa);
                    defer parent.finishArena();

                    const bytes = parent.val.castTag(.bytes).?.data;
                    assert(bytes.len == parent.ty.arrayLenIncludingSentinel());
                    const elems = try arena.alloc(Value, bytes.len);
                    for (elems) |*elem, i| {
                        elem.* = try Value.Tag.int_u64.create(arena, bytes[i]);
                    }

                    parent.val.* = try Value.Tag.array.create(arena, elems);

                    return ComptimePtrMutationKit{
                        .decl_ref_mut = parent.decl_ref_mut,
                        .val = &elems[elem_ptr.index],
                        .ty = elem_ty,
                    };
                },
                .repeated => {
                    // An array is memory-optimized to store only a single element value, and
                    // that value is understood to be the same for the entire length of the array.
                    // However, now we want to modify an individual field and so the
                    // representation has to change.  If we wanted to avoid this, there would
                    // need to be special detection elsewhere to identify when writing a value to an
                    // array element that is stored using the `repeated` tag, and handle it
                    // without making a call to this function.
                    const arena = parent.beginArena(sema.gpa);
                    defer parent.finishArena();

                    const repeated_val = try parent.val.castTag(.repeated).?.data.copy(arena);
                    const elems = try arena.alloc(Value, parent.ty.arrayLenIncludingSentinel());
                    mem.set(Value, elems, repeated_val);

                    parent.val.* = try Value.Tag.array.create(arena, elems);

                    return ComptimePtrMutationKit{
                        .decl_ref_mut = parent.decl_ref_mut,
                        .val = &elems[elem_ptr.index],
                        .ty = elem_ty,
                    };
                },

                .array => return ComptimePtrMutationKit{
                    .decl_ref_mut = parent.decl_ref_mut,
                    .val = &parent.val.castTag(.array).?.data[elem_ptr.index],
                    .ty = elem_ty,
                },

                else => unreachable,
            }
        },
        .field_ptr => {
            const field_ptr = ptr_val.castTag(.field_ptr).?.data;
            var parent = try beginComptimePtrMutation(sema, block, src, field_ptr.container_ptr);
            const field_index = @intCast(u32, field_ptr.field_index);
            const field_ty = parent.ty.structFieldType(field_index);
            switch (parent.val.tag()) {
                .undef => {
                    // A struct or union has been initialized to undefined at comptime and now we
                    // are for the first time setting a field. We must change the representation
                    // of the struct/union from `undef` to `struct`/`union`.
                    const arena = parent.beginArena(sema.gpa);
                    defer parent.finishArena();

                    switch (parent.ty.zigTypeTag()) {
                        .Struct => {
                            const fields = try arena.alloc(Value, parent.ty.structFieldCount());
                            mem.set(Value, fields, Value.undef);

                            parent.val.* = try Value.Tag.@"struct".create(arena, fields);

                            return ComptimePtrMutationKit{
                                .decl_ref_mut = parent.decl_ref_mut,
                                .val = &fields[field_index],
                                .ty = field_ty,
                            };
                        },
                        .Union => {
                            const payload = try arena.create(Value.Payload.Union);
                            payload.* = .{ .data = .{
                                .tag = try Value.Tag.enum_field_index.create(arena, field_index),
                                .val = Value.undef,
                            } };

                            parent.val.* = Value.initPayload(&payload.base);

                            return ComptimePtrMutationKit{
                                .decl_ref_mut = parent.decl_ref_mut,
                                .val = &payload.data.val,
                                .ty = field_ty,
                            };
                        },
                        else => unreachable,
                    }
                },
                .@"struct" => return ComptimePtrMutationKit{
                    .decl_ref_mut = parent.decl_ref_mut,
                    .val = &parent.val.castTag(.@"struct").?.data[field_index],
                    .ty = field_ty,
                },
                .@"union" => {
                    // We need to set the active field of the union.
                    const arena = parent.beginArena(sema.gpa);
                    defer parent.finishArena();

                    const payload = &parent.val.castTag(.@"union").?.data;
                    payload.tag = try Value.Tag.enum_field_index.create(arena, field_index);

                    return ComptimePtrMutationKit{
                        .decl_ref_mut = parent.decl_ref_mut,
                        .val = &payload.val,
                        .ty = field_ty,
                    };
                },

                else => unreachable,
            }
        },
        .eu_payload_ptr => return sema.fail(block, src, "TODO comptime store to eu_payload_ptr", .{}),
        .opt_payload_ptr => return sema.fail(block, src, "TODO comptime store opt_payload_ptr", .{}),
        .decl_ref => unreachable, // isComptimeMutablePtr() has been checked already
        else => unreachable,
    }
}

const ComptimePtrLoadKit = struct {
    /// The Value of the Decl that owns this memory.
    root_val: Value,
    /// Parent Value.
    val: Value,
    /// The Type of the parent Value.
    ty: Type,
    /// The starting byte offset of `val` from `root_val`.
    byte_offset: usize,
    /// Whether the `root_val` could be mutated by further
    /// semantic analysis and a copy must be performed.
    is_mutable: bool,
};

const ComptimePtrLoadError = CompileError || error{
    RuntimeLoad,
};

fn beginComptimePtrLoad(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_val: Value,
) ComptimePtrLoadError!ComptimePtrLoadKit {
    const target = sema.mod.getTarget();
    switch (ptr_val.tag()) {
        .decl_ref => {
            const decl = ptr_val.castTag(.decl_ref).?.data;
            const decl_val = try decl.value();
            if (decl_val.tag() == .variable) return error.RuntimeLoad;
            return ComptimePtrLoadKit{
                .root_val = decl_val,
                .val = decl_val,
                .ty = decl.ty,
                .byte_offset = 0,
                .is_mutable = false,
            };
        },
        .decl_ref_mut => {
            const decl = ptr_val.castTag(.decl_ref_mut).?.data.decl;
            const decl_val = try decl.value();
            if (decl_val.tag() == .variable) return error.RuntimeLoad;
            return ComptimePtrLoadKit{
                .root_val = decl_val,
                .val = decl_val,
                .ty = decl.ty,
                .byte_offset = 0,
                .is_mutable = true,
            };
        },
        .elem_ptr => {
            const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
            const parent = try beginComptimePtrLoad(sema, block, src, elem_ptr.array_ptr);
            const elem_ty = parent.ty.childType();
            const elem_size = elem_ty.abiSize(target);
            return ComptimePtrLoadKit{
                .root_val = parent.root_val,
                .val = try parent.val.elemValue(sema.arena, elem_ptr.index),
                .ty = elem_ty,
                .byte_offset = parent.byte_offset + elem_size * elem_ptr.index,
                .is_mutable = parent.is_mutable,
            };
        },
        .field_ptr => {
            const field_ptr = ptr_val.castTag(.field_ptr).?.data;
            const parent = try beginComptimePtrLoad(sema, block, src, field_ptr.container_ptr);
            const field_index = @intCast(u32, field_ptr.field_index);
            try sema.resolveTypeLayout(block, src, parent.ty);
            const field_offset = parent.ty.structFieldOffset(field_index, target);
            return ComptimePtrLoadKit{
                .root_val = parent.root_val,
                .val = try parent.val.fieldValue(sema.arena, field_index),
                .ty = parent.ty.structFieldType(field_index),
                .byte_offset = parent.byte_offset + field_offset,
                .is_mutable = parent.is_mutable,
            };
        },
        .eu_payload_ptr => {
            const err_union_ptr = ptr_val.castTag(.eu_payload_ptr).?.data;
            const parent = try beginComptimePtrLoad(sema, block, src, err_union_ptr);
            return ComptimePtrLoadKit{
                .root_val = parent.root_val,
                .val = parent.val.castTag(.eu_payload).?.data,
                .ty = parent.ty.errorUnionPayload(),
                .byte_offset = undefined,
                .is_mutable = parent.is_mutable,
            };
        },
        .opt_payload_ptr => {
            const opt_ptr = ptr_val.castTag(.opt_payload_ptr).?.data;
            const parent = try beginComptimePtrLoad(sema, block, src, opt_ptr);
            return ComptimePtrLoadKit{
                .root_val = parent.root_val,
                .val = parent.val.castTag(.opt_payload).?.data,
                .ty = try parent.ty.optionalChildAlloc(sema.arena),
                .byte_offset = undefined,
                .is_mutable = parent.is_mutable,
            };
        },

        .zero,
        .one,
        .int_u64,
        .int_i64,
        .int_big_positive,
        .int_big_negative,
        .variable,
        .extern_fn,
        .function,
        => return error.RuntimeLoad,

        else => unreachable,
    }
}

fn bitCast(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    // TODO validate the type size and other compile errors
    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
        const target = sema.mod.getTarget();
        const old_ty = sema.typeOf(inst);
        const result_val = try val.bitCast(old_ty, dest_ty, target, sema.gpa, sema.arena);
        return sema.addConstant(dest_ty, result_val);
    }
    try sema.requireRuntimeBlock(block, inst_src);
    return block.addBitCast(dest_ty, inst);
}

fn coerceArrayPtrToSlice(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    if (try sema.resolveDefinedValue(block, inst_src, inst)) |val| {
        const ptr_array_ty = sema.typeOf(inst);
        const array_ty = ptr_array_ty.childType();
        const slice_val = try Value.Tag.slice.create(sema.arena, .{
            .ptr = val,
            .len = try Value.Tag.int_u64.create(sema.arena, array_ty.arrayLen()),
        });
        return sema.addConstant(dest_ty, slice_val);
    }
    try sema.requireRuntimeBlock(block, inst_src);
    return block.addTyOp(.array_to_slice, dest_ty, inst);
}

fn coerceCompatiblePtrs(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
        // The comptime Value representation is compatible with both types.
        return sema.addConstant(dest_ty, val);
    }
    try sema.requireRuntimeBlock(block, inst_src);
    return sema.bitCast(block, dest_ty, inst, inst_src);
}

fn coerceEnumToUnion(
    sema: *Sema,
    block: *Block,
    union_ty: Type,
    union_ty_src: LazySrcLoc,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    const inst_ty = sema.typeOf(inst);

    const tag_ty = union_ty.unionTagType() orelse {
        const msg = msg: {
            const msg = try sema.errMsg(block, inst_src, "expected {}, found {}", .{
                union_ty, inst_ty,
            });
            errdefer msg.destroy(sema.gpa);
            try sema.errNote(block, union_ty_src, msg, "cannot coerce enum to untagged union", .{});
            try sema.addDeclaredHereNote(msg, union_ty);
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    };

    const enum_tag = try sema.coerce(block, tag_ty, inst, inst_src);
    if (try sema.resolveDefinedValue(block, inst_src, enum_tag)) |val| {
        const union_obj = union_ty.cast(Type.Payload.Union).?.data;
        const field_index = union_obj.tag_ty.enumTagFieldIndex(val) orelse {
            const msg = msg: {
                const msg = try sema.errMsg(block, inst_src, "union {} has no tag with value {}", .{
                    union_ty, val,
                });
                errdefer msg.destroy(sema.gpa);
                try sema.addDeclaredHereNote(msg, union_ty);
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        };
        const field = union_obj.fields.values()[field_index];
        const field_ty = try sema.resolveTypeFields(block, inst_src, field.ty);
        const opv = (try sema.typeHasOnePossibleValue(block, inst_src, field_ty)) orelse {
            // TODO resolve the field names and include in the error message,
            // also instead of 'union declared here' make it 'field "foo" declared here'.
            const msg = msg: {
                const msg = try sema.errMsg(block, inst_src, "coercion to union {} must initialize {} field", .{
                    union_ty, field_ty,
                });
                errdefer msg.destroy(sema.gpa);
                try sema.addDeclaredHereNote(msg, union_ty);
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(msg);
        };

        return sema.addConstant(union_ty, try Value.Tag.@"union".create(sema.arena, .{
            .tag = val,
            .val = opv,
        }));
    }

    try sema.requireRuntimeBlock(block, inst_src);

    if (tag_ty.isNonexhaustiveEnum()) {
        const msg = msg: {
            const msg = try sema.errMsg(block, inst_src, "runtime coercion to union {} from non-exhaustive enum", .{
                union_ty,
            });
            errdefer msg.destroy(sema.gpa);
            try sema.addDeclaredHereNote(msg, tag_ty);
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }

    // If the union has all fields 0 bits, the union value is just the enum value.
    if (union_ty.unionHasAllZeroBitFieldTypes()) {
        return block.addBitCast(union_ty, enum_tag);
    }

    // TODO resolve the field names and add a hint that says "field 'foo' has type 'bar'"
    // instead of the "union declared here" hint
    const msg = msg: {
        const msg = try sema.errMsg(block, inst_src, "runtime coercion to union {} which has non-void fields", .{
            union_ty,
        });
        errdefer msg.destroy(sema.gpa);
        try sema.addDeclaredHereNote(msg, union_ty);
        break :msg msg;
    };
    return sema.failWithOwnedErrorMsg(msg);
}

// Coerces vectors/arrays which have the same in-memory layout. This can be used for
// both coercing from and to vectors.
fn coerceVectorInMemory(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    dest_ty_src: LazySrcLoc,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    const inst_ty = sema.typeOf(inst);
    const inst_len = inst_ty.arrayLen();
    const dest_len = dest_ty.arrayLen();

    if (dest_len != inst_len) {
        const msg = msg: {
            const msg = try sema.errMsg(block, inst_src, "expected {}, found {}", .{
                dest_ty, inst_ty,
            });
            errdefer msg.destroy(sema.gpa);
            try sema.errNote(block, dest_ty_src, msg, "destination has length {d}", .{dest_len});
            try sema.errNote(block, inst_src, msg, "source has length {d}", .{inst_len});
            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }

    const target = sema.mod.getTarget();
    const dest_elem_ty = dest_ty.childType();
    const inst_elem_ty = inst_ty.childType();
    const in_memory_result = coerceInMemoryAllowed(dest_elem_ty, inst_elem_ty, false, target);
    if (in_memory_result != .ok) {
        // TODO recursive error notes for coerceInMemoryAllowed failure
        return sema.fail(block, inst_src, "expected {}, found {}", .{ dest_ty, inst_ty });
    }

    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |inst_val| {
        // These types share the same comptime value representation.
        return sema.addConstant(dest_ty, inst_val);
    }

    try sema.requireRuntimeBlock(block, inst_src);
    return block.addBitCast(dest_ty, inst);
}

fn coerceCompatibleErrorSets(
    sema: *Sema,
    block: *Block,
    err_set: Air.Inst.Ref,
    err_set_src: LazySrcLoc,
) !Air.Inst.Ref {
    if (try sema.resolveDefinedValue(block, err_set_src, err_set)) |err_set_val| {
        // Same representation works.
        return sema.addConstant(Type.anyerror, err_set_val);
    }
    try sema.requireRuntimeBlock(block, err_set_src);
    return block.addInst(.{
        .tag = .bitcast,
        .data = .{ .ty_op = .{
            .ty = Air.Inst.Ref.anyerror_type,
            .operand = err_set,
        } },
    });
}

fn analyzeDeclVal(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    decl: *Decl,
) CompileError!Air.Inst.Ref {
    if (sema.decl_val_table.get(decl)) |result| {
        return result;
    }
    const decl_ref = try sema.analyzeDeclRef(decl);
    const result = try sema.analyzeLoad(block, src, decl_ref, src);
    if (Air.refToIndex(result)) |index| {
        if (sema.air_instructions.items(.tag)[index] == .constant) {
            try sema.decl_val_table.put(sema.gpa, decl, result);
        }
    }
    return result;
}

fn ensureDeclAnalyzed(sema: *Sema, decl: *Decl) CompileError!void {
    sema.mod.ensureDeclAnalyzed(decl) catch |err| {
        if (sema.owner_func) |owner_func| {
            owner_func.state = .dependency_failure;
        } else {
            sema.owner_decl.analysis = .dependency_failure;
        }
        return err;
    };
}

fn analyzeDeclRef(sema: *Sema, decl: *Decl) CompileError!Air.Inst.Ref {
    try sema.mod.declareDeclDependency(sema.owner_decl, decl);
    try sema.ensureDeclAnalyzed(decl);

    const decl_tv = try decl.typedValue();
    if (decl_tv.val.castTag(.variable)) |payload| {
        const variable = payload.data;
        const alignment: u32 = if (decl.align_val.tag() == .null_value)
            0
        else
            @intCast(u32, decl.align_val.toUnsignedInt());
        const ty = try Type.ptr(sema.arena, .{
            .pointee_type = decl_tv.ty,
            .mutable = variable.is_mutable,
            .@"addrspace" = decl.@"addrspace",
            .@"align" = alignment,
        });
        return sema.addConstant(ty, try Value.Tag.decl_ref.create(sema.arena, decl));
    }
    return sema.addConstant(
        try Type.ptr(sema.arena, .{
            .pointee_type = decl_tv.ty,
            .mutable = false,
            .@"addrspace" = decl.@"addrspace",
        }),
        try Value.Tag.decl_ref.create(sema.arena, decl),
    );
}

fn analyzeRef(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    operand: Air.Inst.Ref,
) CompileError!Air.Inst.Ref {
    const operand_ty = sema.typeOf(operand);

    if (try sema.resolveMaybeUndefVal(block, src, operand)) |val| {
        var anon_decl = try block.startAnonDecl();
        defer anon_decl.deinit();
        return sema.analyzeDeclRef(try anon_decl.finish(
            try operand_ty.copy(anon_decl.arena()),
            try val.copy(anon_decl.arena()),
        ));
    }

    try sema.requireRuntimeBlock(block, src);
    const address_space = target_util.defaultAddressSpace(sema.mod.getTarget(), .local);
    const ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = operand_ty,
        .mutable = false,
        .@"addrspace" = address_space,
    });
    const mut_ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = operand_ty,
        .@"addrspace" = address_space,
    });
    const alloc = try block.addTy(.alloc, mut_ptr_type);
    try sema.storePtr(block, src, alloc, operand);

    // TODO: Replace with sema.coerce when that supports adding pointer constness.
    return sema.bitCast(block, ptr_type, alloc, src);
}

fn analyzeLoad(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr: Air.Inst.Ref,
    ptr_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const ptr_ty = sema.typeOf(ptr);
    const elem_ty = switch (ptr_ty.zigTypeTag()) {
        .Pointer => ptr_ty.childType(),
        else => return sema.fail(block, ptr_src, "expected pointer, found '{}'", .{ptr_ty}),
    };
    if (try sema.resolveDefinedValue(block, ptr_src, ptr)) |ptr_val| {
        if (try sema.pointerDeref(block, ptr_src, ptr_val, ptr_ty)) |elem_val| {
            return sema.addConstant(elem_ty, elem_val);
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.load, elem_ty, ptr);
}

fn analyzeSlicePtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    slice: Air.Inst.Ref,
    slice_ty: Type,
    slice_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const buf = try sema.arena.create(Type.SlicePtrFieldTypeBuffer);
    const result_ty = slice_ty.slicePtrFieldType(buf);

    if (try sema.resolveMaybeUndefVal(block, slice_src, slice)) |val| {
        if (val.isUndef()) return sema.addConstUndef(result_ty);
        return sema.addConstant(result_ty, val.slicePtr());
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.slice_ptr, result_ty, slice);
}

fn analyzeSliceLen(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    slice_inst: Air.Inst.Ref,
) CompileError!Air.Inst.Ref {
    if (try sema.resolveMaybeUndefVal(block, src, slice_inst)) |slice_val| {
        if (slice_val.isUndef()) {
            return sema.addConstUndef(Type.usize);
        }
        return sema.addIntUnsigned(Type.usize, slice_val.sliceLen());
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addTyOp(.slice_len, Type.usize, slice_inst);
}

fn analyzeIsNull(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    operand: Air.Inst.Ref,
    invert_logic: bool,
) CompileError!Air.Inst.Ref {
    const result_ty = Type.initTag(.bool);
    if (try sema.resolveMaybeUndefVal(block, src, operand)) |opt_val| {
        if (opt_val.isUndef()) {
            return sema.addConstUndef(result_ty);
        }
        const is_null = opt_val.isNull();
        const bool_value = if (invert_logic) !is_null else is_null;
        if (bool_value) {
            return Air.Inst.Ref.bool_true;
        } else {
            return Air.Inst.Ref.bool_false;
        }
    }
    try sema.requireRuntimeBlock(block, src);
    const air_tag: Air.Inst.Tag = if (invert_logic) .is_non_null else .is_null;
    return block.addUnOp(air_tag, operand);
}

fn analyzeIsNonErr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    operand: Air.Inst.Ref,
) CompileError!Air.Inst.Ref {
    const operand_ty = sema.typeOf(operand);
    const ot = operand_ty.zigTypeTag();
    if (ot != .ErrorSet and ot != .ErrorUnion) return Air.Inst.Ref.bool_true;
    if (ot == .ErrorSet) return Air.Inst.Ref.bool_false;
    assert(ot == .ErrorUnion);
    const result_ty = Type.initTag(.bool);
    if (try sema.resolveMaybeUndefVal(block, src, operand)) |err_union| {
        if (err_union.isUndef()) {
            return sema.addConstUndef(result_ty);
        }
        if (err_union.getError() == null) {
            return Air.Inst.Ref.bool_true;
        } else {
            return Air.Inst.Ref.bool_false;
        }
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(.is_non_err, operand);
}

fn analyzeSlice(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_ptr: Air.Inst.Ref,
    uncasted_start: Air.Inst.Ref,
    uncasted_end_opt: Air.Inst.Ref,
    sentinel_opt: Air.Inst.Ref,
    sentinel_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const ptr_src = src; // TODO better source location
    const start_src = src; // TODO better source location
    const end_src = src; // TODO better source location
    // Slice expressions can operate on a variable whose type is an array. This requires
    // the slice operand to be a pointer. In the case of a non-array, it will be a double pointer.
    const ptr_ptr_ty = sema.typeOf(ptr_ptr);
    const ptr_ptr_child_ty = switch (ptr_ptr_ty.zigTypeTag()) {
        .Pointer => ptr_ptr_ty.elemType(),
        else => return sema.fail(block, ptr_src, "expected pointer, found '{}'", .{ptr_ptr_ty}),
    };

    var array_ty = ptr_ptr_child_ty;
    var slice_ty = ptr_ptr_ty;
    var ptr_or_slice = ptr_ptr;
    var elem_ty = ptr_ptr_child_ty.childType();
    switch (ptr_ptr_child_ty.zigTypeTag()) {
        .Array => {},
        .Pointer => switch (ptr_ptr_child_ty.ptrSize()) {
            .One => {
                const double_child_ty = ptr_ptr_child_ty.childType();
                if (double_child_ty.zigTypeTag() == .Array) {
                    ptr_or_slice = try sema.analyzeLoad(block, src, ptr_ptr, ptr_src);
                    slice_ty = ptr_ptr_child_ty;
                    array_ty = double_child_ty;
                    elem_ty = double_child_ty.childType();
                } else {
                    return sema.fail(block, ptr_src, "slice of single-item pointer", .{});
                }
            },
            .Many, .C => {
                ptr_or_slice = try sema.analyzeLoad(block, src, ptr_ptr, ptr_src);
                slice_ty = ptr_ptr_child_ty;
                array_ty = ptr_ptr_child_ty;
                elem_ty = ptr_ptr_child_ty.childType();
            },
            .Slice => {
                ptr_or_slice = try sema.analyzeLoad(block, src, ptr_ptr, ptr_src);
                slice_ty = ptr_ptr_child_ty;
                array_ty = ptr_ptr_child_ty;
                elem_ty = ptr_ptr_child_ty.childType();
            },
        },
        else => return sema.fail(block, ptr_src, "slice of non-array type '{}'", .{ptr_ptr_child_ty}),
    }

    const ptr = if (slice_ty.isSlice())
        try sema.analyzeSlicePtr(block, src, ptr_or_slice, slice_ty, ptr_src)
    else
        ptr_or_slice;

    const start = try sema.coerce(block, Type.usize, uncasted_start, start_src);
    const new_ptr = try analyzePtrArithmetic(sema, block, src, ptr, start, .ptr_add, ptr_src, start_src);

    const end = e: {
        if (uncasted_end_opt != .none) {
            break :e try sema.coerce(block, Type.usize, uncasted_end_opt, end_src);
        }

        if (array_ty.zigTypeTag() == .Array) {
            break :e try sema.addConstant(
                Type.usize,
                try Value.Tag.int_u64.create(sema.arena, array_ty.arrayLen()),
            );
        } else if (slice_ty.isSlice()) {
            break :e try sema.analyzeSliceLen(block, src, ptr_or_slice);
        }
        return sema.fail(block, end_src, "slice of pointer must include end value", .{});
    };

    const slice_sentinel = if (sentinel_opt != .none) blk: {
        const casted = try sema.coerce(block, elem_ty, sentinel_opt, sentinel_src);
        break :blk try sema.resolveConstValue(block, sentinel_src, casted);
    } else null;

    const new_len = try sema.analyzeArithmetic(block, .sub, end, start, src, end_src, start_src);

    const opt_new_len_val = try sema.resolveDefinedValue(block, src, new_len);

    const new_ptr_ty_info = sema.typeOf(new_ptr).ptrInfo().data;
    const new_allowzero = new_ptr_ty_info.@"allowzero" and sema.typeOf(ptr).ptrSize() != .C;

    if (opt_new_len_val) |new_len_val| {
        const new_len_int = new_len_val.toUnsignedInt();

        const sentinel = if (array_ty.zigTypeTag() == .Array and new_len_int == array_ty.arrayLen())
            array_ty.sentinel()
        else
            slice_sentinel;

        const return_ty = try Type.ptr(sema.arena, .{
            .pointee_type = try Type.array(sema.arena, new_len_int, sentinel, elem_ty),
            .sentinel = null,
            .@"align" = new_ptr_ty_info.@"align",
            .@"addrspace" = new_ptr_ty_info.@"addrspace",
            .mutable = new_ptr_ty_info.mutable,
            .@"allowzero" = new_allowzero,
            .@"volatile" = new_ptr_ty_info.@"volatile",
            .size = .One,
        });

        const opt_new_ptr_val = try sema.resolveMaybeUndefVal(block, ptr_src, new_ptr);
        const new_ptr_val = opt_new_ptr_val orelse {
            return block.addBitCast(return_ty, new_ptr);
        };

        if (!new_ptr_val.isUndef()) {
            return sema.addConstant(return_ty, new_ptr_val);
        }

        // Special case: @as([]i32, undefined)[x..x]
        if (new_len_int == 0) {
            return sema.addConstUndef(return_ty);
        }

        return sema.fail(block, ptr_src, "non-zero length slice of undefined pointer", .{});
    }

    const return_ty = try Type.ptr(sema.arena, .{
        .pointee_type = elem_ty,
        .sentinel = slice_sentinel,
        .@"align" = new_ptr_ty_info.@"align",
        .@"addrspace" = new_ptr_ty_info.@"addrspace",
        .mutable = new_ptr_ty_info.mutable,
        .@"allowzero" = new_allowzero,
        .@"volatile" = new_ptr_ty_info.@"volatile",
        .size = .Slice,
    });

    try sema.requireRuntimeBlock(block, src);
    return block.addInst(.{
        .tag = .slice,
        .data = .{ .ty_pl = .{
            .ty = try sema.addType(return_ty),
            .payload = try sema.addExtra(Air.Bin{
                .lhs = new_ptr,
                .rhs = new_len,
            }),
        } },
    });
}

/// Asserts that lhs and rhs types are both numeric.
fn cmpNumeric(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
    op: std.math.CompareOperator,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) CompileError!Air.Inst.Ref {
    const lhs_ty = sema.typeOf(lhs);
    const rhs_ty = sema.typeOf(rhs);

    assert(lhs_ty.isNumeric());
    assert(rhs_ty.isNumeric());

    const lhs_ty_tag = lhs_ty.zigTypeTag();
    const rhs_ty_tag = rhs_ty.zigTypeTag();

    if (lhs_ty_tag == .Vector and rhs_ty_tag == .Vector) {
        if (lhs_ty.arrayLen() != rhs_ty.arrayLen()) {
            return sema.fail(block, src, "vector length mismatch: {d} and {d}", .{
                lhs_ty.arrayLen(), rhs_ty.arrayLen(),
            });
        }
        return sema.fail(block, src, "TODO implement support for vectors in cmpNumeric", .{});
    } else if (lhs_ty_tag == .Vector or rhs_ty_tag == .Vector) {
        return sema.fail(block, src, "mixed scalar and vector operands to comparison operator: '{}' and '{}'", .{
            lhs_ty, rhs_ty,
        });
    }

    const runtime_src: LazySrcLoc = src: {
        if (try sema.resolveMaybeUndefVal(block, lhs_src, lhs)) |lhs_val| {
            if (try sema.resolveMaybeUndefVal(block, rhs_src, rhs)) |rhs_val| {
                if (lhs_val.isUndef() or rhs_val.isUndef()) {
                    return sema.addConstUndef(Type.initTag(.bool));
                }
                if (Value.compareHetero(lhs_val, op, rhs_val)) {
                    return Air.Inst.Ref.bool_true;
                } else {
                    return Air.Inst.Ref.bool_false;
                }
            } else {
                break :src rhs_src;
            }
        } else {
            break :src lhs_src;
        }
    };

    // TODO handle comparisons against lazy zero values
    // Some values can be compared against zero without being runtime known or without forcing
    // a full resolution of their value, for example `@sizeOf(@Frame(function))` is known to
    // always be nonzero, and we benefit from not forcing the full evaluation and stack frame layout
    // of this function if we don't need to.
    try sema.requireRuntimeBlock(block, runtime_src);

    // For floats, emit a float comparison instruction.
    const lhs_is_float = switch (lhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    const rhs_is_float = switch (rhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    const target = sema.mod.getTarget();
    if (lhs_is_float and rhs_is_float) {
        // Implicit cast the smaller one to the larger one.
        const dest_ty = x: {
            if (lhs_ty_tag == .ComptimeFloat) {
                break :x rhs_ty;
            } else if (rhs_ty_tag == .ComptimeFloat) {
                break :x lhs_ty;
            }
            if (lhs_ty.floatBits(target) >= rhs_ty.floatBits(target)) {
                break :x lhs_ty;
            } else {
                break :x rhs_ty;
            }
        };
        const casted_lhs = try sema.coerce(block, dest_ty, lhs, lhs_src);
        const casted_rhs = try sema.coerce(block, dest_ty, rhs, rhs_src);
        return block.addBinOp(Air.Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
    }
    // For mixed unsigned integer sizes, implicit cast both operands to the larger integer.
    // For mixed signed and unsigned integers, implicit cast both operands to a signed
    // integer with + 1 bit.
    // For mixed floats and integers, extract the integer part from the float, cast that to
    // a signed integer with mantissa bits + 1, and if there was any non-integral part of the float,
    // add/subtract 1.
    const lhs_is_signed = if (try sema.resolveDefinedValue(block, lhs_src, lhs)) |lhs_val|
        lhs_val.compareWithZero(.lt)
    else
        (lhs_ty.isRuntimeFloat() or lhs_ty.isSignedInt());
    const rhs_is_signed = if (try sema.resolveDefinedValue(block, rhs_src, rhs)) |rhs_val|
        rhs_val.compareWithZero(.lt)
    else
        (rhs_ty.isRuntimeFloat() or rhs_ty.isSignedInt());
    const dest_int_is_signed = lhs_is_signed or rhs_is_signed;

    var dest_float_type: ?Type = null;

    var lhs_bits: usize = undefined;
    if (try sema.resolveMaybeUndefVal(block, lhs_src, lhs)) |lhs_val| {
        if (lhs_val.isUndef())
            return sema.addConstUndef(Type.initTag(.bool));
        const is_unsigned = if (lhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try lhs_val.toBigInt(&bigint_space).toManaged(sema.gpa);
            defer bigint.deinit();
            const zcmp = lhs_val.orderAgainstZero();
            if (lhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return Air.Inst.Ref.bool_false,
                    .neq => return Air.Inst.Ref.bool_true,
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            lhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            lhs_bits = lhs_val.intBitCountTwosComp();
            break :x (lhs_val.orderAgainstZero() != .lt);
        };
        lhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (lhs_is_float) {
        dest_float_type = lhs_ty;
    } else {
        const int_info = lhs_ty.intInfo(target);
        lhs_bits = int_info.bits + @boolToInt(int_info.signedness == .unsigned and dest_int_is_signed);
    }

    var rhs_bits: usize = undefined;
    if (try sema.resolveMaybeUndefVal(block, rhs_src, rhs)) |rhs_val| {
        if (rhs_val.isUndef())
            return sema.addConstUndef(Type.initTag(.bool));
        const is_unsigned = if (rhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try rhs_val.toBigInt(&bigint_space).toManaged(sema.gpa);
            defer bigint.deinit();
            const zcmp = rhs_val.orderAgainstZero();
            if (rhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return Air.Inst.Ref.bool_false,
                    .neq => return Air.Inst.Ref.bool_true,
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            rhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            rhs_bits = rhs_val.intBitCountTwosComp();
            break :x (rhs_val.orderAgainstZero() != .lt);
        };
        rhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (rhs_is_float) {
        dest_float_type = rhs_ty;
    } else {
        const int_info = rhs_ty.intInfo(target);
        rhs_bits = int_info.bits + @boolToInt(int_info.signedness == .unsigned and dest_int_is_signed);
    }

    const dest_ty = if (dest_float_type) |ft| ft else blk: {
        const max_bits = std.math.max(lhs_bits, rhs_bits);
        const casted_bits = std.math.cast(u16, max_bits) catch |err| switch (err) {
            error.Overflow => return sema.fail(block, src, "{d} exceeds maximum integer bit count", .{max_bits}),
        };
        const signedness: std.builtin.Signedness = if (dest_int_is_signed) .signed else .unsigned;
        break :blk try Module.makeIntType(sema.arena, signedness, casted_bits);
    };
    const casted_lhs = try sema.coerce(block, dest_ty, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, dest_ty, rhs, rhs_src);

    return block.addBinOp(Air.Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
}

fn wrapOptional(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
        return sema.addConstant(dest_ty, try Value.Tag.opt_payload.create(sema.arena, val));
    }

    try sema.requireRuntimeBlock(block, inst_src);
    return block.addTyOp(.wrap_optional, dest_ty, inst);
}

fn wrapErrorUnion(
    sema: *Sema,
    block: *Block,
    dest_ty: Type,
    inst: Air.Inst.Ref,
    inst_src: LazySrcLoc,
) !Air.Inst.Ref {
    const inst_ty = sema.typeOf(inst);
    const dest_err_set_ty = dest_ty.errorUnionSet();
    const dest_payload_ty = dest_ty.errorUnionPayload();
    if (try sema.resolveMaybeUndefVal(block, inst_src, inst)) |val| {
        if (inst_ty.zigTypeTag() != .ErrorSet) {
            _ = try sema.coerce(block, dest_payload_ty, inst, inst_src);
            return sema.addConstant(dest_ty, try Value.Tag.eu_payload.create(sema.arena, val));
        }
        switch (dest_err_set_ty.tag()) {
            .anyerror => {},
            .error_set_single => ok: {
                const expected_name = val.castTag(.@"error").?.data.name;
                const n = dest_err_set_ty.castTag(.error_set_single).?.data;
                if (mem.eql(u8, expected_name, n)) break :ok;
                return sema.failWithErrorSetCodeMissing(block, inst_src, dest_err_set_ty, inst_ty);
            },
            .error_set => ok: {
                const expected_name = val.castTag(.@"error").?.data.name;
                const error_set = dest_err_set_ty.castTag(.error_set).?.data;
                const names = error_set.names_ptr[0..error_set.names_len];
                // TODO this is O(N). I'm putting off solving this until we solve inferred
                // error sets at the same time.
                for (names) |name| {
                    if (mem.eql(u8, expected_name, name)) break :ok;
                }
                return sema.failWithErrorSetCodeMissing(block, inst_src, dest_err_set_ty, inst_ty);
            },
            .error_set_inferred => ok: {
                const err_set_payload = dest_err_set_ty.castTag(.error_set_inferred).?.data;
                if (err_set_payload.is_anyerror) break :ok;
                const expected_name = val.castTag(.@"error").?.data.name;
                if (err_set_payload.map.contains(expected_name)) break :ok;
                // TODO error set resolution here before emitting a compile error
                return sema.failWithErrorSetCodeMissing(block, inst_src, dest_err_set_ty, inst_ty);
            },
            else => unreachable,
        }
        return sema.addConstant(dest_ty, val);
    }

    try sema.requireRuntimeBlock(block, inst_src);

    // we are coercing from E to E!T
    if (inst_ty.zigTypeTag() == .ErrorSet) {
        var coerced = try sema.coerce(block, dest_err_set_ty, inst, inst_src);
        return block.addTyOp(.wrap_errunion_err, dest_ty, coerced);
    } else {
        var coerced = try sema.coerce(block, dest_payload_ty, inst, inst_src);
        return block.addTyOp(.wrap_errunion_payload, dest_ty, coerced);
    }
}

fn unionToTag(
    sema: *Sema,
    block: *Block,
    enum_ty: Type,
    un: Air.Inst.Ref,
    un_src: LazySrcLoc,
) !Air.Inst.Ref {
    if ((try sema.typeHasOnePossibleValue(block, un_src, enum_ty))) |opv| {
        return sema.addConstant(enum_ty, opv);
    }
    if (try sema.resolveMaybeUndefVal(block, un_src, un)) |un_val| {
        return sema.addConstant(enum_ty, un_val.unionTag());
    }
    try sema.requireRuntimeBlock(block, un_src);
    return block.addTyOp(.get_union_tag, enum_ty, un);
}

fn resolvePeerTypes(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    instructions: []Air.Inst.Ref,
    candidate_srcs: Module.PeerTypeCandidateSrc,
) !Type {
    if (instructions.len == 0)
        return Type.initTag(.noreturn);

    if (instructions.len == 1)
        return sema.typeOf(instructions[0]);

    const target = sema.mod.getTarget();

    var chosen = instructions[0];
    var any_are_null = false;
    var chosen_i: usize = 0;
    for (instructions[1..]) |candidate, candidate_i| {
        const candidate_ty = sema.typeOf(candidate);
        const chosen_ty = sema.typeOf(chosen);
        if (candidate_ty.eql(chosen_ty))
            continue;
        const candidate_ty_tag = candidate_ty.zigTypeTag();
        const chosen_ty_tag = chosen_ty.zigTypeTag();

        switch (candidate_ty_tag) {
            .NoReturn, .Undefined => continue,

            .Null => {
                any_are_null = true;
                continue;
            },

            .Int => switch (chosen_ty_tag) {
                .ComptimeInt => {
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                },
                .Int => {
                    if (chosen_ty.isSignedInt() == candidate_ty.isSignedInt()) {
                        if (chosen_ty.intInfo(target).bits < candidate_ty.intInfo(target).bits) {
                            chosen = candidate;
                            chosen_i = candidate_i + 1;
                        }
                        continue;
                    }
                },
                .Pointer => if (chosen_ty.ptrSize() == .C) continue,
                else => {},
            },
            .ComptimeInt => switch (chosen_ty_tag) {
                .Int, .Float, .ComptimeFloat => continue,
                .Pointer => if (chosen_ty.ptrSize() == .C) continue,
                else => {},
            },
            .Float => switch (chosen_ty_tag) {
                .Float => {
                    if (chosen_ty.floatBits(target) < candidate_ty.floatBits(target)) {
                        chosen = candidate;
                        chosen_i = candidate_i + 1;
                    }
                    continue;
                },
                .ComptimeFloat, .ComptimeInt => {
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                },
                else => {},
            },
            .ComptimeFloat => switch (chosen_ty_tag) {
                .Float => continue,
                .ComptimeInt => {
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                },
                else => {},
            },
            .Enum => switch (chosen_ty_tag) {
                .EnumLiteral => {
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                },
                else => {},
            },
            .EnumLiteral => switch (chosen_ty_tag) {
                .Enum => continue,
                else => {},
            },
            .Pointer => {
                if (candidate_ty.ptrSize() == .C) {
                    if (chosen_ty_tag == .Int or chosen_ty_tag == .ComptimeInt) {
                        chosen = candidate;
                        chosen_i = candidate_i + 1;
                        continue;
                    }
                    if (chosen_ty_tag == .Pointer and chosen_ty.ptrSize() != .Slice) {
                        continue;
                    }
                }
            },
            .Optional => {
                var opt_child_buf: Type.Payload.ElemType = undefined;
                const opt_child_ty = candidate_ty.optionalChild(&opt_child_buf);
                if (coerceInMemoryAllowed(opt_child_ty, chosen_ty, false, target) == .ok) {
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                }
                if (coerceInMemoryAllowed(chosen_ty, opt_child_ty, false, target) == .ok) {
                    any_are_null = true;
                    continue;
                }
            },
            else => {},
        }

        switch (chosen_ty_tag) {
            .NoReturn, .Undefined => {
                chosen = candidate;
                chosen_i = candidate_i + 1;
                continue;
            },
            .Null => {
                any_are_null = true;
                chosen = candidate;
                chosen_i = candidate_i + 1;
                continue;
            },
            .Optional => {
                var opt_child_buf: Type.Payload.ElemType = undefined;
                const opt_child_ty = chosen_ty.optionalChild(&opt_child_buf);
                if (coerceInMemoryAllowed(opt_child_ty, candidate_ty, false, target) == .ok) {
                    continue;
                }
                if (coerceInMemoryAllowed(candidate_ty, opt_child_ty, false, target) == .ok) {
                    any_are_null = true;
                    chosen = candidate;
                    chosen_i = candidate_i + 1;
                    continue;
                }
            },
            else => {},
        }

        // At this point, we hit a compile error. We need to recover
        // the source locations.
        const chosen_src = candidate_srcs.resolve(
            sema.gpa,
            block.src_decl,
            chosen_i,
        );
        const candidate_src = candidate_srcs.resolve(
            sema.gpa,
            block.src_decl,
            candidate_i + 1,
        );

        const msg = msg: {
            const msg = try sema.errMsg(block, src, "incompatible types: '{}' and '{}'", .{ chosen_ty, candidate_ty });
            errdefer msg.destroy(sema.gpa);

            if (chosen_src) |src_loc|
                try sema.errNote(block, src_loc, msg, "type '{}' here", .{chosen_ty});

            if (candidate_src) |src_loc|
                try sema.errNote(block, src_loc, msg, "type '{}' here", .{candidate_ty});

            break :msg msg;
        };
        return sema.failWithOwnedErrorMsg(msg);
    }

    const chosen_ty = sema.typeOf(chosen);

    if (any_are_null) {
        switch (chosen_ty.zigTypeTag()) {
            .Null, .Optional => return chosen_ty,
            else => return Type.optional(sema.arena, chosen_ty),
        }
    }

    return chosen_ty;
}

pub fn resolveTypeLayout(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ty: Type,
) CompileError!void {
    switch (ty.zigTypeTag()) {
        .Struct => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const struct_obj = resolved_ty.castTag(.@"struct").?.data;
            switch (struct_obj.status) {
                .none, .have_field_types => {},
                .field_types_wip, .layout_wip => {
                    return sema.fail(block, src, "struct {} depends on itself", .{ty});
                },
                .have_layout => return,
            }
            struct_obj.status = .layout_wip;
            for (struct_obj.fields.values()) |field| {
                try sema.resolveTypeLayout(block, src, field.ty);
            }
            struct_obj.status = .have_layout;
        },
        .Union => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const union_obj = resolved_ty.cast(Type.Payload.Union).?.data;
            switch (union_obj.status) {
                .none, .have_field_types => {},
                .field_types_wip, .layout_wip => {
                    return sema.fail(block, src, "union {} depends on itself", .{ty});
                },
                .have_layout => return,
            }
            union_obj.status = .layout_wip;
            for (union_obj.fields.values()) |field| {
                try sema.resolveTypeLayout(block, src, field.ty);
            }
            union_obj.status = .have_layout;
        },
        .Array => {
            const elem_ty = ty.childType();
            return sema.resolveTypeLayout(block, src, elem_ty);
        },
        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            const payload_ty = ty.optionalChild(&buf);
            return sema.resolveTypeLayout(block, src, payload_ty);
        },
        .ErrorUnion => {
            const payload_ty = ty.errorUnionPayload();
            return sema.resolveTypeLayout(block, src, payload_ty);
        },
        else => {},
    }
}

fn resolveTypeFields(sema: *Sema, block: *Block, src: LazySrcLoc, ty: Type) CompileError!Type {
    switch (ty.tag()) {
        .@"struct" => {
            const struct_obj = ty.castTag(.@"struct").?.data;
            switch (struct_obj.status) {
                .none => {},
                .field_types_wip => {
                    return sema.fail(block, src, "struct {} depends on itself", .{ty});
                },
                .have_field_types, .have_layout, .layout_wip => return ty,
            }

            struct_obj.status = .field_types_wip;
            try semaStructFields(sema.mod, struct_obj);
            struct_obj.status = .have_field_types;

            return ty;
        },
        .type_info => return sema.resolveBuiltinTypeFields(block, src, "TypeInfo"),
        .extern_options => return sema.resolveBuiltinTypeFields(block, src, "ExternOptions"),
        .export_options => return sema.resolveBuiltinTypeFields(block, src, "ExportOptions"),
        .atomic_order => return sema.resolveBuiltinTypeFields(block, src, "AtomicOrder"),
        .atomic_rmw_op => return sema.resolveBuiltinTypeFields(block, src, "AtomicRmwOp"),
        .calling_convention => return sema.resolveBuiltinTypeFields(block, src, "CallingConvention"),
        .address_space => return sema.resolveBuiltinTypeFields(block, src, "AddressSpace"),
        .float_mode => return sema.resolveBuiltinTypeFields(block, src, "FloatMode"),
        .reduce_op => return sema.resolveBuiltinTypeFields(block, src, "ReduceOp"),
        .call_options => return sema.resolveBuiltinTypeFields(block, src, "CallOptions"),

        .@"union", .union_tagged => {
            const union_obj = ty.cast(Type.Payload.Union).?.data;
            switch (union_obj.status) {
                .none => {},
                .field_types_wip => {
                    return sema.fail(block, src, "union {} depends on itself", .{ty});
                },
                .have_field_types, .have_layout, .layout_wip => return ty,
            }

            union_obj.status = .field_types_wip;
            try semaUnionFields(sema.mod, union_obj);
            union_obj.status = .have_field_types;

            return ty;
        },
        else => return ty,
    }
}

fn resolveBuiltinTypeFields(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    name: []const u8,
) CompileError!Type {
    const resolved_ty = try sema.getBuiltinType(block, src, name);
    return sema.resolveTypeFields(block, src, resolved_ty);
}

fn semaStructFields(
    mod: *Module,
    struct_obj: *Module.Struct,
) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
    const decl = struct_obj.owner_decl;
    const zir = struct_obj.namespace.file_scope.zir;
    const extended = zir.instructions.items(.data)[struct_obj.zir_index].extended;
    assert(extended.opcode == .struct_decl);
    const small = @bitCast(Zir.Inst.StructDecl.Small, extended.small);
    var extra_index: usize = extended.operand;

    const src: LazySrcLoc = .{ .node_offset = struct_obj.node_offset };
    extra_index += @boolToInt(small.has_src_node);

    const body_len = if (small.has_body_len) blk: {
        const body_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk body_len;
    } else 0;

    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    const decls_len = if (small.has_decls_len) decls_len: {
        const decls_len = zir.extra[extra_index];
        extra_index += 1;
        break :decls_len decls_len;
    } else 0;

    // Skip over decls.
    var decls_it = zir.declIteratorInner(extra_index, decls_len);
    while (decls_it.next()) |_| {}
    extra_index = decls_it.extra_index;

    const body = zir.extra[extra_index..][0..body_len];
    if (fields_len == 0) {
        assert(body.len == 0);
        return;
    }
    extra_index += body.len;

    var decl_arena = decl.value_arena.?.promote(gpa);
    defer decl.value_arena.?.* = decl_arena.state;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = &analysis_arena.allocator,
        .perm_arena = &decl_arena.allocator,
        .code = zir,
        .owner_decl = decl,
        .func = null,
        .fn_ret_ty = Type.void,
        .owner_func = null,
    };
    defer sema.deinit();

    var wip_captures = try WipCaptureScope.init(gpa, &decl_arena.allocator, decl.src_scope);
    defer wip_captures.deinit();

    var block_scope: Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl,
        .namespace = &struct_obj.namespace,
        .wip_capture_scope = wip_captures.scope,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer {
        assert(block_scope.instructions.items.len == 0);
        block_scope.params.deinit(gpa);
    }

    if (body.len != 0) {
        _ = try sema.analyzeBody(&block_scope, body);
    }

    try wip_captures.finalize();

    try struct_obj.fields.ensureTotalCapacity(&decl_arena.allocator, fields_len);

    const bits_per_field = 4;
    const fields_per_u32 = 32 / bits_per_field;
    const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
    var bit_bag_index: usize = extra_index;
    extra_index += bit_bags_count;
    var cur_bit_bag: u32 = undefined;
    var field_i: u32 = 0;
    while (field_i < fields_len) : (field_i += 1) {
        if (field_i % fields_per_u32 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_default = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const is_comptime = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const unused = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        _ = unused;

        const field_name_zir = zir.nullTerminatedString(zir.extra[extra_index]);
        extra_index += 1;
        const field_type_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        extra_index += 1;

        // This string needs to outlive the ZIR code.
        const field_name = try decl_arena.allocator.dupe(u8, field_name_zir);
        const field_ty: Type = if (field_type_ref == .none)
            Type.initTag(.noreturn)
        else
            // TODO: if we need to report an error here, use a source location
            // that points to this type expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            try sema.resolveType(&block_scope, src, field_type_ref);

        const gop = struct_obj.fields.getOrPutAssumeCapacity(field_name);
        assert(!gop.found_existing);
        gop.value_ptr.* = .{
            .ty = try field_ty.copy(&decl_arena.allocator),
            .abi_align = Value.initTag(.abi_align_default),
            .default_val = Value.initTag(.unreachable_value),
            .is_comptime = is_comptime,
            .offset = undefined,
        };

        if (has_align) {
            const align_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
            extra_index += 1;
            // TODO: if we need to report an error here, use a source location
            // that points to this alignment expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            const abi_align_val = (try sema.resolveInstConst(&block_scope, src, align_ref)).val;
            gop.value_ptr.abi_align = try abi_align_val.copy(&decl_arena.allocator);
        }
        if (has_default) {
            const default_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
            extra_index += 1;
            const default_inst = sema.resolveInst(default_ref);
            // TODO: if we need to report an error here, use a source location
            // that points to this default value expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            const default_val = (try sema.resolveMaybeUndefVal(&block_scope, src, default_inst)) orelse
                return sema.failWithNeededComptime(&block_scope, src);
            gop.value_ptr.default_val = try default_val.copy(&decl_arena.allocator);
        }
    }
}

fn semaUnionFields(mod: *Module, union_obj: *Module.Union) CompileError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
    const decl = union_obj.owner_decl;
    const zir = union_obj.namespace.file_scope.zir;
    const extended = zir.instructions.items(.data)[union_obj.zir_index].extended;
    assert(extended.opcode == .union_decl);
    const small = @bitCast(Zir.Inst.UnionDecl.Small, extended.small);
    var extra_index: usize = extended.operand;

    const src: LazySrcLoc = .{ .node_offset = union_obj.node_offset };
    extra_index += @boolToInt(small.has_src_node);

    const tag_type_ref: Zir.Inst.Ref = if (small.has_tag_type) blk: {
        const ty_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        extra_index += 1;
        break :blk ty_ref;
    } else .none;

    const body_len = if (small.has_body_len) blk: {
        const body_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk body_len;
    } else 0;

    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    const decls_len = if (small.has_decls_len) decls_len: {
        const decls_len = zir.extra[extra_index];
        extra_index += 1;
        break :decls_len decls_len;
    } else 0;

    // Skip over decls.
    var decls_it = zir.declIteratorInner(extra_index, decls_len);
    while (decls_it.next()) |_| {}
    extra_index = decls_it.extra_index;

    const body = zir.extra[extra_index..][0..body_len];
    if (fields_len == 0) {
        assert(body.len == 0);
        return;
    }
    extra_index += body.len;

    var decl_arena = union_obj.owner_decl.value_arena.?.promote(gpa);
    defer union_obj.owner_decl.value_arena.?.* = decl_arena.state;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = &analysis_arena.allocator,
        .perm_arena = &decl_arena.allocator,
        .code = zir,
        .owner_decl = decl,
        .func = null,
        .fn_ret_ty = Type.void,
        .owner_func = null,
    };
    defer sema.deinit();

    var wip_captures = try WipCaptureScope.init(gpa, &decl_arena.allocator, decl.src_scope);
    defer wip_captures.deinit();

    var block_scope: Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl,
        .namespace = &union_obj.namespace,
        .wip_capture_scope = wip_captures.scope,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer {
        assert(block_scope.instructions.items.len == 0);
        block_scope.params.deinit(gpa);
    }

    if (body.len != 0) {
        _ = try sema.analyzeBody(&block_scope, body);
    }

    try wip_captures.finalize();

    try union_obj.fields.ensureTotalCapacity(&decl_arena.allocator, fields_len);

    var int_tag_ty: Type = undefined;
    var enum_field_names: ?*Module.EnumNumbered.NameMap = null;
    var enum_value_map: ?*Module.EnumNumbered.ValueMap = null;
    if (tag_type_ref != .none) {
        const provided_ty = try sema.resolveType(&block_scope, src, tag_type_ref);
        if (small.auto_enum_tag) {
            // The provided type is an integer type and we must construct the enum tag type here.
            int_tag_ty = provided_ty;
            union_obj.tag_ty = try sema.generateUnionTagTypeNumbered(&block_scope, fields_len, provided_ty);
            enum_field_names = &union_obj.tag_ty.castTag(.enum_numbered).?.data.fields;
            enum_value_map = &union_obj.tag_ty.castTag(.enum_numbered).?.data.values;
        } else {
            // The provided type is the enum tag type.
            union_obj.tag_ty = provided_ty;
        }
    } else {
        // If auto_enum_tag is false, this is an untagged union. However, for semantic analysis
        // purposes, we still auto-generate an enum tag type the same way. That the union is
        // untagged is represented by the Type tag (union vs union_tagged).
        union_obj.tag_ty = try sema.generateUnionTagTypeSimple(&block_scope, fields_len);
        enum_field_names = &union_obj.tag_ty.castTag(.enum_simple).?.data.fields;
    }

    const bits_per_field = 4;
    const fields_per_u32 = 32 / bits_per_field;
    const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
    var bit_bag_index: usize = extra_index;
    extra_index += bit_bags_count;
    var cur_bit_bag: u32 = undefined;
    var field_i: u32 = 0;
    while (field_i < fields_len) : (field_i += 1) {
        if (field_i % fields_per_u32 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const has_type = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_tag = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const unused = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        _ = unused;

        const field_name_zir = zir.nullTerminatedString(zir.extra[extra_index]);
        extra_index += 1;

        const field_type_ref: Zir.Inst.Ref = if (has_type) blk: {
            const field_type_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
            extra_index += 1;
            break :blk field_type_ref;
        } else .none;

        const align_ref: Zir.Inst.Ref = if (has_align) blk: {
            const align_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
            extra_index += 1;
            break :blk align_ref;
        } else .none;

        const tag_ref: Zir.Inst.Ref = if (has_tag) blk: {
            const tag_ref = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
            extra_index += 1;
            break :blk tag_ref;
        } else .none;

        if (enum_value_map) |map| {
            const tag_src = src; // TODO better source location
            const coerced = try sema.coerce(&block_scope, int_tag_ty, tag_ref, tag_src);
            const val = try sema.resolveConstValue(&block_scope, tag_src, coerced);
            map.putAssumeCapacityContext(val, {}, .{ .ty = int_tag_ty });
        }

        // This string needs to outlive the ZIR code.
        const field_name = try decl_arena.allocator.dupe(u8, field_name_zir);
        if (enum_field_names) |set| {
            set.putAssumeCapacity(field_name, {});
        }

        const field_ty: Type = if (!has_type)
            Type.void
        else if (field_type_ref == .none)
            Type.initTag(.noreturn)
        else
            // TODO: if we need to report an error here, use a source location
            // that points to this type expression rather than the union.
            // But only resolve the source location if we need to emit a compile error.
            try sema.resolveType(&block_scope, src, field_type_ref);

        const gop = union_obj.fields.getOrPutAssumeCapacity(field_name);
        assert(!gop.found_existing);
        gop.value_ptr.* = .{
            .ty = try field_ty.copy(&decl_arena.allocator),
            .abi_align = Value.initTag(.abi_align_default),
        };

        if (align_ref != .none) {
            // TODO: if we need to report an error here, use a source location
            // that points to this alignment expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            const abi_align_val = (try sema.resolveInstConst(&block_scope, src, align_ref)).val;
            gop.value_ptr.abi_align = try abi_align_val.copy(&decl_arena.allocator);
        } else {
            gop.value_ptr.abi_align = Value.initTag(.abi_align_default);
        }
    }
}

fn generateUnionTagTypeNumbered(
    sema: *Sema,
    block: *Block,
    fields_len: u32,
    int_ty: Type,
) !Type {
    const mod = sema.mod;

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const enum_obj = try new_decl_arena.allocator.create(Module.EnumNumbered);
    const enum_ty_payload = try new_decl_arena.allocator.create(Type.Payload.EnumNumbered);
    enum_ty_payload.* = .{
        .base = .{ .tag = .enum_numbered },
        .data = enum_obj,
    };
    const enum_ty = Type.initPayload(&enum_ty_payload.base);
    const enum_val = try Value.Tag.ty.create(&new_decl_arena.allocator, enum_ty);
    // TODO better type name
    const new_decl = try mod.createAnonymousDecl(block, .{
        .ty = Type.type,
        .val = enum_val,
    });
    new_decl.owns_tv = true;
    errdefer mod.abortAnonDecl(new_decl);

    enum_obj.* = .{
        .owner_decl = new_decl,
        .tag_ty = int_ty,
        .fields = .{},
        .values = .{},
        .node_offset = 0,
    };
    // Here we pre-allocate the maps using the decl arena.
    try enum_obj.fields.ensureTotalCapacity(&new_decl_arena.allocator, fields_len);
    try enum_obj.values.ensureTotalCapacityContext(&new_decl_arena.allocator, fields_len, .{ .ty = int_ty });
    try new_decl.finalizeNewArena(&new_decl_arena);
    return enum_ty;
}

fn generateUnionTagTypeSimple(sema: *Sema, block: *Block, fields_len: u32) !Type {
    const mod = sema.mod;

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const enum_obj = try new_decl_arena.allocator.create(Module.EnumSimple);
    const enum_ty_payload = try new_decl_arena.allocator.create(Type.Payload.EnumSimple);
    enum_ty_payload.* = .{
        .base = .{ .tag = .enum_simple },
        .data = enum_obj,
    };
    const enum_ty = Type.initPayload(&enum_ty_payload.base);
    const enum_val = try Value.Tag.ty.create(&new_decl_arena.allocator, enum_ty);
    // TODO better type name
    const new_decl = try mod.createAnonymousDecl(block, .{
        .ty = Type.type,
        .val = enum_val,
    });
    new_decl.owns_tv = true;
    errdefer mod.abortAnonDecl(new_decl);

    enum_obj.* = .{
        .owner_decl = new_decl,
        .fields = .{},
        .node_offset = 0,
    };
    // Here we pre-allocate the maps using the decl arena.
    try enum_obj.fields.ensureTotalCapacity(&new_decl_arena.allocator, fields_len);
    try new_decl.finalizeNewArena(&new_decl_arena);
    return enum_ty;
}

fn getBuiltin(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    name: []const u8,
) CompileError!Air.Inst.Ref {
    const mod = sema.mod;
    const std_pkg = mod.main_pkg.table.get("std").?;
    const std_file = (mod.importPkg(std_pkg) catch unreachable).file;
    const opt_builtin_inst = try sema.namespaceLookupRef(
        block,
        src,
        std_file.root_decl.?.src_namespace,
        "builtin",
    );
    const builtin_inst = try sema.analyzeLoad(block, src, opt_builtin_inst.?, src);
    const builtin_ty = try sema.analyzeAsType(block, src, builtin_inst);
    const opt_ty_inst = try sema.namespaceLookupRef(
        block,
        src,
        builtin_ty.getNamespace().?,
        name,
    );
    return sema.analyzeLoad(block, src, opt_ty_inst.?, src);
}

fn getBuiltinType(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    name: []const u8,
) CompileError!Type {
    const ty_inst = try sema.getBuiltin(block, src, name);
    return sema.analyzeAsType(block, src, ty_inst);
}

/// There is another implementation of this in `Type.onePossibleValue`. This one
/// in `Sema` is for calling during semantic analysis, and performs field resolution
/// to get the answer. The one in `Type` is for calling during codegen and asserts
/// that the types are already resolved.
fn typeHasOnePossibleValue(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ty: Type,
) CompileError!?Value {
    switch (ty.tag()) {
        .f16,
        .f32,
        .f64,
        .f128,
        .c_longdouble,
        .comptime_int,
        .comptime_float,
        .u1,
        .u8,
        .i8,
        .u16,
        .i16,
        .u32,
        .i32,
        .u64,
        .i64,
        .u128,
        .i128,
        .usize,
        .isize,
        .c_short,
        .c_ushort,
        .c_int,
        .c_uint,
        .c_long,
        .c_ulong,
        .c_longlong,
        .c_ulonglong,
        .bool,
        .type,
        .anyerror,
        .fn_noreturn_no_args,
        .fn_void_no_args,
        .fn_naked_noreturn_no_args,
        .fn_ccc_void_no_args,
        .function,
        .single_const_pointer_to_comptime_int,
        .array_sentinel,
        .array_u8_sentinel_0,
        .const_slice_u8,
        .const_slice,
        .mut_slice,
        .c_void,
        .optional,
        .optional_single_mut_pointer,
        .optional_single_const_pointer,
        .enum_literal,
        .anyerror_void_error_union,
        .error_union,
        .error_set,
        .error_set_single,
        .error_set_inferred,
        .@"opaque",
        .var_args_param,
        .manyptr_u8,
        .manyptr_const_u8,
        .atomic_order,
        .atomic_rmw_op,
        .calling_convention,
        .address_space,
        .float_mode,
        .reduce_op,
        .call_options,
        .export_options,
        .extern_options,
        .type_info,
        .@"anyframe",
        .anyframe_T,
        .many_const_pointer,
        .many_mut_pointer,
        .c_const_pointer,
        .c_mut_pointer,
        .single_const_pointer,
        .single_mut_pointer,
        .pointer,
        .bound_fn,
        => return null,

        .@"struct" => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const s = resolved_ty.castTag(.@"struct").?.data;
            for (s.fields.values()) |value| {
                if ((try sema.typeHasOnePossibleValue(block, src, value.ty)) == null) {
                    return null;
                }
            }
            return Value.initTag(.empty_struct_value);
        },
        .enum_numbered => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const enum_obj = resolved_ty.castTag(.enum_numbered).?.data;
            if (enum_obj.fields.count() == 1) {
                if (enum_obj.values.count() == 0) {
                    return Value.zero; // auto-numbered
                } else {
                    return enum_obj.values.keys()[0];
                }
            } else {
                return null;
            }
        },
        .enum_full => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const enum_obj = resolved_ty.castTag(.enum_full).?.data;
            if (enum_obj.fields.count() == 1) {
                if (enum_obj.values.count() == 0) {
                    return Value.zero; // auto-numbered
                } else {
                    return enum_obj.values.keys()[0];
                }
            } else {
                return null;
            }
        },
        .enum_simple => {
            const resolved_ty = try sema.resolveTypeFields(block, src, ty);
            const enum_simple = resolved_ty.castTag(.enum_simple).?.data;
            if (enum_simple.fields.count() == 1) {
                return Value.zero;
            } else {
                return null;
            }
        },
        .enum_nonexhaustive => {
            const tag_ty = ty.castTag(.enum_nonexhaustive).?.data.tag_ty;
            if (!tag_ty.hasCodeGenBits()) {
                return Value.zero;
            } else {
                return null;
            }
        },
        .@"union" => {
            return null; // TODO
        },
        .union_tagged => {
            return null; // TODO
        },

        .empty_struct, .empty_struct_literal => return Value.initTag(.empty_struct_value),
        .void => return Value.void,
        .noreturn => return Value.initTag(.unreachable_value),
        .@"null" => return Value.@"null",
        .@"undefined" => return Value.initTag(.undef),

        .int_unsigned, .int_signed => {
            if (ty.cast(Type.Payload.Bits).?.data == 0) {
                return Value.zero;
            } else {
                return null;
            }
        },
        .vector, .array, .array_u8 => {
            if (ty.arrayLen() == 0)
                return Value.initTag(.empty_array);
            if ((try sema.typeHasOnePossibleValue(block, src, ty.elemType())) != null) {
                return Value.initTag(.the_only_possible_value);
            }
            return null;
        },

        .inferred_alloc_const => unreachable,
        .inferred_alloc_mut => unreachable,
        .generic_poison => return error.GenericPoison,
    }
}

fn getAstTree(sema: *Sema, block: *Block) CompileError!*const std.zig.Ast {
    return block.namespace.file_scope.getTree(sema.gpa) catch |err| {
        log.err("unable to load AST to report compile error: {s}", .{@errorName(err)});
        return error.AnalysisFail;
    };
}

fn enumFieldSrcLoc(
    decl: *Decl,
    tree: std.zig.Ast,
    node_offset: i32,
    field_index: usize,
) LazySrcLoc {
    @setCold(true);
    const enum_node = decl.relativeToNodeIndex(node_offset);
    const node_tags = tree.nodes.items(.tag);
    var buffer: [2]std.zig.Ast.Node.Index = undefined;
    const container_decl = switch (node_tags[enum_node]) {
        .container_decl,
        .container_decl_trailing,
        => tree.containerDecl(enum_node),

        .container_decl_two,
        .container_decl_two_trailing,
        => tree.containerDeclTwo(&buffer, enum_node),

        .container_decl_arg,
        .container_decl_arg_trailing,
        => tree.containerDeclArg(enum_node),

        else => unreachable,
    };
    var it_index: usize = 0;
    for (container_decl.ast.members) |member_node| {
        switch (node_tags[member_node]) {
            .container_field_init,
            .container_field_align,
            .container_field,
            => {
                if (it_index == field_index) {
                    return .{ .node_offset = decl.nodeIndexToRelative(member_node) };
                }
                it_index += 1;
            },

            else => continue,
        }
    } else unreachable;
}

/// Returns the type of the AIR instruction.
fn typeOf(sema: *Sema, inst: Air.Inst.Ref) Type {
    return sema.getTmpAir().typeOf(inst);
}

fn getTmpAir(sema: Sema) Air {
    return .{
        .instructions = sema.air_instructions.slice(),
        .extra = sema.air_extra.items,
        .values = sema.air_values.items,
    };
}

pub fn addType(sema: *Sema, ty: Type) !Air.Inst.Ref {
    switch (ty.tag()) {
        .u1 => return .u1_type,
        .u8 => return .u8_type,
        .i8 => return .i8_type,
        .u16 => return .u16_type,
        .i16 => return .i16_type,
        .u32 => return .u32_type,
        .i32 => return .i32_type,
        .u64 => return .u64_type,
        .i64 => return .i64_type,
        .u128 => return .u128_type,
        .i128 => return .i128_type,
        .usize => return .usize_type,
        .isize => return .isize_type,
        .c_short => return .c_short_type,
        .c_ushort => return .c_ushort_type,
        .c_int => return .c_int_type,
        .c_uint => return .c_uint_type,
        .c_long => return .c_long_type,
        .c_ulong => return .c_ulong_type,
        .c_longlong => return .c_longlong_type,
        .c_ulonglong => return .c_ulonglong_type,
        .c_longdouble => return .c_longdouble_type,
        .f16 => return .f16_type,
        .f32 => return .f32_type,
        .f64 => return .f64_type,
        .f128 => return .f128_type,
        .c_void => return .c_void_type,
        .bool => return .bool_type,
        .void => return .void_type,
        .type => return .type_type,
        .anyerror => return .anyerror_type,
        .comptime_int => return .comptime_int_type,
        .comptime_float => return .comptime_float_type,
        .noreturn => return .noreturn_type,
        .@"anyframe" => return .anyframe_type,
        .@"null" => return .null_type,
        .@"undefined" => return .undefined_type,
        .enum_literal => return .enum_literal_type,
        .atomic_order => return .atomic_order_type,
        .atomic_rmw_op => return .atomic_rmw_op_type,
        .calling_convention => return .calling_convention_type,
        .address_space => return .address_space_type,
        .float_mode => return .float_mode_type,
        .reduce_op => return .reduce_op_type,
        .call_options => return .call_options_type,
        .export_options => return .export_options_type,
        .extern_options => return .extern_options_type,
        .type_info => return .type_info_type,
        .manyptr_u8 => return .manyptr_u8_type,
        .manyptr_const_u8 => return .manyptr_const_u8_type,
        .fn_noreturn_no_args => return .fn_noreturn_no_args_type,
        .fn_void_no_args => return .fn_void_no_args_type,
        .fn_naked_noreturn_no_args => return .fn_naked_noreturn_no_args_type,
        .fn_ccc_void_no_args => return .fn_ccc_void_no_args_type,
        .single_const_pointer_to_comptime_int => return .single_const_pointer_to_comptime_int_type,
        .const_slice_u8 => return .const_slice_u8_type,
        .anyerror_void_error_union => return .anyerror_void_error_union_type,
        .generic_poison => return .generic_poison_type,
        else => {},
    }
    try sema.air_instructions.append(sema.gpa, .{
        .tag = .const_ty,
        .data = .{ .ty = ty },
    });
    return Air.indexToRef(@intCast(u32, sema.air_instructions.len - 1));
}

fn addIntUnsigned(sema: *Sema, ty: Type, int: u64) CompileError!Air.Inst.Ref {
    return sema.addConstant(ty, try Value.Tag.int_u64.create(sema.arena, int));
}

fn addConstUndef(sema: *Sema, ty: Type) CompileError!Air.Inst.Ref {
    return sema.addConstant(ty, Value.initTag(.undef));
}

pub fn addConstant(sema: *Sema, ty: Type, val: Value) SemaError!Air.Inst.Ref {
    const gpa = sema.gpa;
    const ty_inst = try sema.addType(ty);
    try sema.air_values.append(gpa, val);
    try sema.air_instructions.append(gpa, .{
        .tag = .constant,
        .data = .{ .ty_pl = .{
            .ty = ty_inst,
            .payload = @intCast(u32, sema.air_values.items.len - 1),
        } },
    });
    return Air.indexToRef(@intCast(u32, sema.air_instructions.len - 1));
}

pub fn addExtra(sema: *Sema, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try sema.air_extra.ensureUnusedCapacity(sema.gpa, fields.len);
    return addExtraAssumeCapacity(sema, extra);
}

pub fn addExtraAssumeCapacity(sema: *Sema, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, sema.air_extra.items.len);
    inline for (fields) |field| {
        sema.air_extra.appendAssumeCapacity(switch (field.field_type) {
            u32 => @field(extra, field.name),
            Air.Inst.Ref => @enumToInt(@field(extra, field.name)),
            i32 => @bitCast(u32, @field(extra, field.name)),
            else => @compileError("bad field type"),
        });
    }
    return result;
}

fn appendRefsAssumeCapacity(sema: *Sema, refs: []const Air.Inst.Ref) void {
    const coerced = @bitCast([]const u32, refs);
    sema.air_extra.appendSliceAssumeCapacity(coerced);
}

fn getBreakBlock(sema: *Sema, inst_index: Air.Inst.Index) ?Air.Inst.Index {
    const air_datas = sema.air_instructions.items(.data);
    const air_tags = sema.air_instructions.items(.tag);
    switch (air_tags[inst_index]) {
        .br => return air_datas[inst_index].br.block_inst,
        else => return null,
    }
}

fn isComptimeKnown(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    inst: Air.Inst.Ref,
) !bool {
    return (try sema.resolveMaybeUndefVal(block, src, inst)) != null;
}

fn analyzeComptimeAlloc(
    sema: *Sema,
    block: *Block,
    var_type: Type,
    alignment: u32,
) CompileError!Air.Inst.Ref {
    const ptr_type = try Type.ptr(sema.arena, .{
        .pointee_type = var_type,
        .@"addrspace" = target_util.defaultAddressSpace(sema.mod.getTarget(), .global_constant),
        .@"align" = alignment,
    });

    var anon_decl = try block.startAnonDecl();
    defer anon_decl.deinit();

    const align_val = if (alignment == 0)
        Value.@"null"
    else
        try Value.Tag.int_u64.create(anon_decl.arena(), alignment);

    const decl = try anon_decl.finish(
        try var_type.copy(anon_decl.arena()),
        // There will be stores before the first load, but they may be to sub-elements or
        // sub-fields. So we need to initialize with undef to allow the mechanism to expand
        // into fields/elements and have those overridden with stored values.
        Value.undef,
    );
    decl.align_val = align_val;

    try sema.mod.declareDeclDependency(sema.owner_decl, decl);
    return sema.addConstant(ptr_type, try Value.Tag.decl_ref_mut.create(sema.arena, .{
        .runtime_index = block.runtime_index,
        .decl = decl,
    }));
}

/// The places where a user can specify an address space attribute
pub const AddressSpaceContext = enum {
    /// A function is specified to be placed in a certain address space.
    function,

    /// A (global) variable is specified to be placed in a certain address space.
    /// In contrast to .constant, these values (and thus the address space they will be
    /// placed in) are required to be mutable.
    variable,

    /// A (global) constant value is specified to be placed in a certain address space.
    /// In contrast to .variable, values placed in this address space are not required to be mutable.
    constant,

    /// A pointer is ascripted to point into a certain address space.
    pointer,
};

pub fn analyzeAddrspace(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    zir_ref: Zir.Inst.Ref,
    ctx: AddressSpaceContext,
) !std.builtin.AddressSpace {
    const addrspace_tv = try sema.resolveInstConst(block, src, zir_ref);
    const address_space = addrspace_tv.val.toEnum(std.builtin.AddressSpace);
    const target = sema.mod.getTarget();
    const arch = target.cpu.arch;

    const supported = switch (address_space) {
        .generic => true,
        .gs, .fs, .ss => (arch == .i386 or arch == .x86_64) and ctx == .pointer,
    };

    if (!supported) {
        // TODO error messages could be made more elaborate here
        const entity = switch (ctx) {
            .function => "functions",
            .variable => "mutable values",
            .constant => "constant values",
            .pointer => "pointers",
        };

        return sema.fail(
            block,
            src,
            "{s} with address space '{s}' are not supported on {s}",
            .{ entity, @tagName(address_space), arch.genericName() },
        );
    }

    return address_space;
}

/// Asserts the value is a pointer and dereferences it.
/// Returns `null` if the pointer contents cannot be loaded at comptime.
fn pointerDeref(sema: *Sema, block: *Block, src: LazySrcLoc, ptr_val: Value, ptr_ty: Type) CompileError!?Value {
    const target = sema.mod.getTarget();
    const load_ty = ptr_ty.childType();
    const parent = sema.beginComptimePtrLoad(block, src, ptr_val) catch |err| switch (err) {
        error.RuntimeLoad => return null,
        else => |e| return e,
    };
    // We have a Value that lines up in virtual memory exactly with what we want to load.
    // If the Type is in-memory coercable to `load_ty`, it may be returned without modifications.
    const coerce_in_mem_ok =
        coerceInMemoryAllowed(load_ty, parent.ty, false, target) == .ok or
        coerceInMemoryAllowed(parent.ty, load_ty, false, target) == .ok;
    if (coerce_in_mem_ok) {
        if (parent.is_mutable) {
            // The decl whose value we are obtaining here may be overwritten with
            // a different value upon further semantic analysis, which would
            // invalidate this memory. So we must copy here.
            return try parent.val.copy(sema.arena);
        }
        return parent.val;
    }

    // The type is not in-memory coercable, so it must be bitcasted according
    // to the pointer type we are performing the load through.

    // TODO emit a compile error if the types are not allowed to be bitcasted

    if (parent.ty.abiSize(target) >= load_ty.abiSize(target)) {
        // The Type it is stored as in the compiler has an ABI size greater or equal to
        // the ABI size of `load_ty`. We may perform the bitcast based on
        // `parent.val` alone (more efficient).
        return try parent.val.bitCast(parent.ty, load_ty, target, sema.gpa, sema.arena);
    }

    // The Type it is stored as in the compiler has an ABI size less than the ABI size
    // of `load_ty`. The bitcast must be performed based on the `parent.root_val`
    // and reinterpreted starting at `parent.byte_offset`.
    return sema.fail(block, src, "TODO: implement bitcast with index offset", .{});
}
