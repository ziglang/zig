//! Semantic analysis of ZIR instructions.
//! Shared to every Block. Stored on the stack.
//! State used for compiling a `zir.Code` into TZIR.
//! Transforms untyped ZIR instructions into semantically-analyzed TZIR instructions.
//! Does type checking, comptime control flow, and safety-check generation.
//! This is the the heart of the Zig compiler.

mod: *Module,
/// Alias to `mod.gpa`.
gpa: *Allocator,
/// Points to the arena allocator of the Decl.
arena: *Allocator,
code: zir.Code,
/// Maps ZIR to TZIR.
inst_map: []*Inst,
/// When analyzing an inline function call, owner_decl is the Decl of the caller
/// and `src_decl` of `Scope.Block` is the `Decl` of the callee.
/// This `Decl` owns the arena memory of this `Sema`.
owner_decl: *Decl,
/// For an inline or comptime function call, this will be the root parent function
/// which contains the callsite. Corresponds to `owner_decl`.
owner_func: ?*Module.Fn,
/// The function this ZIR code is the body of, according to the source code.
/// This starts out the same as `owner_func` and then diverges in the case of
/// an inline or comptime function call.
func: ?*Module.Fn,
/// For now, TZIR requires arg instructions to be the first N instructions in the
/// TZIR code. We store references here for the purpose of `resolveInst`.
/// This can get reworked with TZIR memory layout changes, into simply:
/// > Denormalized data to make `resolveInst` faster. This is 0 if not inside a function,
/// > otherwise it is the number of parameters of the function.
/// > param_count: u32
param_inst_list: []const *ir.Inst,
branch_quota: u32 = 1000,
branch_count: u32 = 0,
/// This field is updated when a new source location becomes active, so that
/// instructions which do not have explicitly mapped source locations still have
/// access to the source location set by the previous instruction which did
/// contain a mapped source location.
src: LazySrcLoc = .{ .token_offset = 0 },

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.sema);

const Sema = @This();
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const ir = @import("ir.zig");
const zir = @import("zir.zig");
const Module = @import("Module.zig");
const Inst = ir.Inst;
const Body = ir.Body;
const trace = @import("tracy.zig").trace;
const Scope = Module.Scope;
const InnerError = Module.InnerError;
const Decl = Module.Decl;
const LazySrcLoc = Module.LazySrcLoc;
const RangeSet = @import("RangeSet.zig");
const AstGen = @import("AstGen.zig");

pub fn root(sema: *Sema, root_block: *Scope.Block) !zir.Inst.Index {
    const inst_data = sema.code.instructions.items(.data)[0].pl_node;
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);
    const root_body = sema.code.extra[extra.end..][0..extra.data.body_len];
    return sema.analyzeBody(root_block, root_body);
}

pub fn rootAsRef(sema: *Sema, root_block: *Scope.Block) !zir.Inst.Ref {
    const break_inst = try sema.root(root_block);
    return sema.code.instructions.items(.data)[break_inst].@"break".operand;
}

/// Assumes that `root_block` ends with `break_inline`.
pub fn rootAsType(sema: *Sema, root_block: *Scope.Block) !Type {
    assert(root_block.is_comptime);
    const zir_inst_ref = try sema.rootAsRef(root_block);
    // Source location is unneeded because resolveConstValue must have already
    // been successfully called when coercing the value to a type, from the
    // result location.
    return sema.resolveType(root_block, .unneeded, zir_inst_ref);
}

/// Returns only the result from the body that is specified.
/// Only appropriate to call when it is determined at comptime that this body
/// has no peers.
fn resolveBody(sema: *Sema, block: *Scope.Block, body: []const zir.Inst.Index) InnerError!*Inst {
    const break_inst = try sema.analyzeBody(block, body);
    const operand_ref = sema.code.instructions.items(.data)[break_inst].@"break".operand;
    return sema.resolveInst(operand_ref);
}

/// ZIR instructions which are always `noreturn` return this. This matches the
/// return type of `analyzeBody` so that we can tail call them.
/// Only appropriate to return when the instruction is known to be NoReturn
/// solely based on the ZIR tag.
const always_noreturn: InnerError!zir.Inst.Index = @as(zir.Inst.Index, undefined);

/// This function is the main loop of `Sema` and it can be used in two different ways:
/// * The traditional way where there are N breaks out of the block and peer type
///   resolution is done on the break operands. In this case, the `zir.Inst.Index`
///   part of the return value will be `undefined`, and callsites should ignore it,
///   finding the block result value via the block scope.
/// * The "flat" way. There is only 1 break out of the block, and it is with a `break_inline`
///   instruction. In this case, the `zir.Inst.Index` part of the return value will be
///   the break instruction. This communicates both which block the break applies to, as
///   well as the operand. No block scope needs to be created for this strategy.
pub fn analyzeBody(
    sema: *Sema,
    block: *Scope.Block,
    body: []const zir.Inst.Index,
) InnerError!zir.Inst.Index {
    // No tracy calls here, to avoid interfering with the tail call mechanism.

    const map = block.sema.inst_map;
    const tags = block.sema.code.instructions.items(.tag);
    const datas = block.sema.code.instructions.items(.data);

    // We use a while(true) loop here to avoid a redundant way of breaking out of
    // the loop. The only way to break out of the loop is with a `noreturn`
    // instruction.
    // TODO: As an optimization, make sure the codegen for these switch prongs
    // directly jump to the next one, rather than detouring through the loop
    // continue expression. Related: https://github.com/ziglang/zig/issues/8220
    var i: usize = 0;
    while (true) : (i += 1) {
        const inst = body[i];
        map[inst] = switch (tags[inst]) {
            .elided => continue,

            .add => try sema.zirArithmetic(block, inst),
            .addwrap => try sema.zirArithmetic(block, inst),
            .alloc => try sema.zirAlloc(block, inst),
            .alloc_inferred => try sema.zirAllocInferred(block, inst, Type.initTag(.inferred_alloc_const)),
            .alloc_inferred_mut => try sema.zirAllocInferred(block, inst, Type.initTag(.inferred_alloc_mut)),
            .alloc_mut => try sema.zirAllocMut(block, inst),
            .array_cat => try sema.zirArrayCat(block, inst),
            .array_mul => try sema.zirArrayMul(block, inst),
            .array_type => try sema.zirArrayType(block, inst),
            .array_type_sentinel => try sema.zirArrayTypeSentinel(block, inst),
            .as => try sema.zirAs(block, inst),
            .as_node => try sema.zirAsNode(block, inst),
            .@"asm" => try sema.zirAsm(block, inst, false),
            .asm_volatile => try sema.zirAsm(block, inst, true),
            .bit_and => try sema.zirBitwise(block, inst, .bit_and),
            .bit_not => try sema.zirBitNot(block, inst),
            .bit_or => try sema.zirBitwise(block, inst, .bit_or),
            .bitcast => try sema.zirBitcast(block, inst),
            .bitcast_result_ptr => try sema.zirBitcastResultPtr(block, inst),
            .block => try sema.zirBlock(block, inst),
            .bool_not => try sema.zirBoolNot(block, inst),
            .bool_and => try sema.zirBoolOp(block, inst, false),
            .bool_or => try sema.zirBoolOp(block, inst, true),
            .bool_br_and => try sema.zirBoolBr(block, inst, false),
            .bool_br_or => try sema.zirBoolBr(block, inst, true),
            .call => try sema.zirCall(block, inst, .auto, false),
            .call_chkused => try sema.zirCall(block, inst, .auto, true),
            .call_compile_time => try sema.zirCall(block, inst, .compile_time, false),
            .call_none => try sema.zirCallNone(block, inst, false),
            .call_none_chkused => try sema.zirCallNone(block, inst, true),
            .cmp_eq => try sema.zirCmp(block, inst, .eq),
            .cmp_gt => try sema.zirCmp(block, inst, .gt),
            .cmp_gte => try sema.zirCmp(block, inst, .gte),
            .cmp_lt => try sema.zirCmp(block, inst, .lt),
            .cmp_lte => try sema.zirCmp(block, inst, .lte),
            .cmp_neq => try sema.zirCmp(block, inst, .neq),
            .coerce_result_ptr => try sema.zirCoerceResultPtr(block, inst),
            .decl_ref => try sema.zirDeclRef(block, inst),
            .decl_val => try sema.zirDeclVal(block, inst),
            .load => try sema.zirLoad(block, inst),
            .div => try sema.zirArithmetic(block, inst),
            .elem_ptr => try sema.zirElemPtr(block, inst),
            .elem_ptr_node => try sema.zirElemPtrNode(block, inst),
            .elem_val => try sema.zirElemVal(block, inst),
            .elem_val_node => try sema.zirElemValNode(block, inst),
            .enum_literal => try sema.zirEnumLiteral(block, inst),
            .enum_literal_small => try sema.zirEnumLiteralSmall(block, inst),
            .enum_to_int => try sema.zirEnumToInt(block, inst),
            .int_to_enum => try sema.zirIntToEnum(block, inst),
            .err_union_code => try sema.zirErrUnionCode(block, inst),
            .err_union_code_ptr => try sema.zirErrUnionCodePtr(block, inst),
            .err_union_payload_safe => try sema.zirErrUnionPayload(block, inst, true),
            .err_union_payload_safe_ptr => try sema.zirErrUnionPayloadPtr(block, inst, true),
            .err_union_payload_unsafe => try sema.zirErrUnionPayload(block, inst, false),
            .err_union_payload_unsafe_ptr => try sema.zirErrUnionPayloadPtr(block, inst, false),
            .error_union_type => try sema.zirErrorUnionType(block, inst),
            .error_value => try sema.zirErrorValue(block, inst),
            .error_to_int => try sema.zirErrorToInt(block, inst),
            .int_to_error => try sema.zirIntToError(block, inst),
            .field_ptr => try sema.zirFieldPtr(block, inst),
            .field_ptr_named => try sema.zirFieldPtrNamed(block, inst),
            .field_val => try sema.zirFieldVal(block, inst),
            .field_val_named => try sema.zirFieldValNamed(block, inst),
            .floatcast => try sema.zirFloatcast(block, inst),
            .fn_type => try sema.zirFnType(block, inst, false),
            .fn_type_cc => try sema.zirFnTypeCc(block, inst, false),
            .fn_type_cc_var_args => try sema.zirFnTypeCc(block, inst, true),
            .fn_type_var_args => try sema.zirFnType(block, inst, true),
            .has_decl => try sema.zirHasDecl(block, inst),
            .import => try sema.zirImport(block, inst),
            .indexable_ptr_len => try sema.zirIndexablePtrLen(block, inst),
            .int => try sema.zirInt(block, inst),
            .float => try sema.zirFloat(block, inst),
            .float128 => try sema.zirFloat128(block, inst),
            .int_type => try sema.zirIntType(block, inst),
            .intcast => try sema.zirIntcast(block, inst),
            .is_err => try sema.zirIsErr(block, inst),
            .is_err_ptr => try sema.zirIsErrPtr(block, inst),
            .is_non_null => try sema.zirIsNull(block, inst, true),
            .is_non_null_ptr => try sema.zirIsNullPtr(block, inst, true),
            .is_null => try sema.zirIsNull(block, inst, false),
            .is_null_ptr => try sema.zirIsNullPtr(block, inst, false),
            .loop => try sema.zirLoop(block, inst),
            .merge_error_sets => try sema.zirMergeErrorSets(block, inst),
            .mod_rem => try sema.zirArithmetic(block, inst),
            .mul => try sema.zirArithmetic(block, inst),
            .mulwrap => try sema.zirArithmetic(block, inst),
            .negate => try sema.zirNegate(block, inst, .sub),
            .negate_wrap => try sema.zirNegate(block, inst, .subwrap),
            .optional_payload_safe => try sema.zirOptionalPayload(block, inst, true),
            .optional_payload_safe_ptr => try sema.zirOptionalPayloadPtr(block, inst, true),
            .optional_payload_unsafe => try sema.zirOptionalPayload(block, inst, false),
            .optional_payload_unsafe_ptr => try sema.zirOptionalPayloadPtr(block, inst, false),
            .optional_type => try sema.zirOptionalType(block, inst),
            .optional_type_from_ptr_elem => try sema.zirOptionalTypeFromPtrElem(block, inst),
            .param_type => try sema.zirParamType(block, inst),
            .ptr_type => try sema.zirPtrType(block, inst),
            .ptr_type_simple => try sema.zirPtrTypeSimple(block, inst),
            .ptrtoint => try sema.zirPtrtoint(block, inst),
            .ref => try sema.zirRef(block, inst),
            .ret_ptr => try sema.zirRetPtr(block, inst),
            .ret_type => try sema.zirRetType(block, inst),
            .shl => try sema.zirShl(block, inst),
            .shr => try sema.zirShr(block, inst),
            .slice_end => try sema.zirSliceEnd(block, inst),
            .slice_sentinel => try sema.zirSliceSentinel(block, inst),
            .slice_start => try sema.zirSliceStart(block, inst),
            .str => try sema.zirStr(block, inst),
            .sub => try sema.zirArithmetic(block, inst),
            .subwrap => try sema.zirArithmetic(block, inst),
            .switch_block => try sema.zirSwitchBlock(block, inst, false, .none),
            .switch_block_multi => try sema.zirSwitchBlockMulti(block, inst, false, .none),
            .switch_block_else => try sema.zirSwitchBlock(block, inst, false, .@"else"),
            .switch_block_else_multi => try sema.zirSwitchBlockMulti(block, inst, false, .@"else"),
            .switch_block_under => try sema.zirSwitchBlock(block, inst, false, .under),
            .switch_block_under_multi => try sema.zirSwitchBlockMulti(block, inst, false, .under),
            .switch_block_ref => try sema.zirSwitchBlock(block, inst, true, .none),
            .switch_block_ref_multi => try sema.zirSwitchBlockMulti(block, inst, true, .none),
            .switch_block_ref_else => try sema.zirSwitchBlock(block, inst, true, .@"else"),
            .switch_block_ref_else_multi => try sema.zirSwitchBlockMulti(block, inst, true, .@"else"),
            .switch_block_ref_under => try sema.zirSwitchBlock(block, inst, true, .under),
            .switch_block_ref_under_multi => try sema.zirSwitchBlockMulti(block, inst, true, .under),
            .switch_capture => try sema.zirSwitchCapture(block, inst, false, false),
            .switch_capture_ref => try sema.zirSwitchCapture(block, inst, false, true),
            .switch_capture_multi => try sema.zirSwitchCapture(block, inst, true, false),
            .switch_capture_multi_ref => try sema.zirSwitchCapture(block, inst, true, true),
            .switch_capture_else => try sema.zirSwitchCaptureElse(block, inst, false),
            .switch_capture_else_ref => try sema.zirSwitchCaptureElse(block, inst, true),
            .type_info => try sema.zirTypeInfo(block, inst),
            .typeof => try sema.zirTypeof(block, inst),
            .typeof_elem => try sema.zirTypeofElem(block, inst),
            .typeof_peer => try sema.zirTypeofPeer(block, inst),
            .xor => try sema.zirBitwise(block, inst, .xor),
            .struct_init_empty => try sema.zirStructInitEmpty(block, inst),
            .struct_init => try sema.zirStructInit(block, inst),
            .field_type => try sema.zirFieldType(block, inst),

            .struct_decl => try sema.zirStructDecl(block, inst, .Auto),
            .struct_decl_packed => try sema.zirStructDecl(block, inst, .Packed),
            .struct_decl_extern => try sema.zirStructDecl(block, inst, .Extern),
            .enum_decl => try sema.zirEnumDecl(block, inst, false),
            .enum_decl_nonexhaustive => try sema.zirEnumDecl(block, inst, true),
            .union_decl => try sema.zirUnionDecl(block, inst),
            .opaque_decl => try sema.zirOpaqueDecl(block, inst),

            // Instructions that we know to *always* be noreturn based solely on their tag.
            // These functions match the return type of analyzeBody so that we can
            // tail call them here.
            .condbr => return sema.zirCondbr(block, inst),
            .@"break" => return sema.zirBreak(block, inst),
            .break_inline => return inst,
            .compile_error => return sema.zirCompileError(block, inst),
            .ret_coerce => return sema.zirRetTok(block, inst, true),
            .ret_node => return sema.zirRetNode(block, inst),
            .ret_tok => return sema.zirRetTok(block, inst, false),
            .@"unreachable" => return sema.zirUnreachable(block, inst),
            .repeat => return sema.zirRepeat(block, inst),

            // Instructions that we know can *never* be noreturn based solely on
            // their tag. We avoid needlessly checking if they are noreturn and
            // continue the loop.
            // We also know that they cannot be referenced later, so we avoid
            // putting them into the map.
            .breakpoint => {
                try sema.zirBreakpoint(block, inst);
                continue;
            },
            .dbg_stmt_node => {
                try sema.zirDbgStmtNode(block, inst);
                continue;
            },
            .ensure_err_payload_void => {
                try sema.zirEnsureErrPayloadVoid(block, inst);
                continue;
            },
            .ensure_result_non_error => {
                try sema.zirEnsureResultNonError(block, inst);
                continue;
            },
            .ensure_result_used => {
                try sema.zirEnsureResultUsed(block, inst);
                continue;
            },
            .compile_log => {
                try sema.zirCompileLog(block, inst);
                continue;
            },
            .set_eval_branch_quota => {
                try sema.zirSetEvalBranchQuota(block, inst);
                continue;
            },
            .store => {
                try sema.zirStore(block, inst);
                continue;
            },
            .store_node => {
                try sema.zirStoreNode(block, inst);
                continue;
            },
            .store_to_block_ptr => {
                try sema.zirStoreToBlockPtr(block, inst);
                continue;
            },
            .store_to_inferred_ptr => {
                try sema.zirStoreToInferredPtr(block, inst);
                continue;
            },
            .resolve_inferred_alloc => {
                try sema.zirResolveInferredAlloc(block, inst);
                continue;
            },
            .validate_struct_init_ptr => {
                try sema.zirValidateStructInitPtr(block, inst);
                continue;
            },
            .@"export" => {
                try sema.zirExport(block, inst);
                continue;
            },

            // Special case instructions to handle comptime control flow.
            .repeat_inline => {
                // Send comptime control flow back to the beginning of this block.
                const src: LazySrcLoc = .{ .node_offset = datas[inst].node };
                try sema.emitBackwardBranch(block, src);
                i = 0;
                continue;
            },
            .block_inline => blk: {
                // Directly analyze the block body without introducing a new block.
                const inst_data = datas[inst].pl_node;
                const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);
                const inline_body = sema.code.extra[extra.end..][0..extra.data.body_len];
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk try sema.resolveInst(break_data.operand);
                } else {
                    return break_inst;
                }
            },
            .condbr_inline => blk: {
                const inst_data = datas[inst].pl_node;
                const cond_src: LazySrcLoc = .{ .node_offset_if_cond = inst_data.src_node };
                const extra = sema.code.extraData(zir.Inst.CondBr, inst_data.payload_index);
                const then_body = sema.code.extra[extra.end..][0..extra.data.then_body_len];
                const else_body = sema.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
                const cond = try sema.resolveInstConst(block, cond_src, extra.data.condition);
                const inline_body = if (cond.val.toBool()) then_body else else_body;
                const break_inst = try sema.analyzeBody(block, inline_body);
                const break_data = datas[break_inst].@"break";
                if (inst == break_data.block_inst) {
                    break :blk try sema.resolveInst(break_data.operand);
                } else {
                    return break_inst;
                }
            },
        };
        if (map[inst].ty.isNoReturn())
            return always_noreturn;
    }
}

/// TODO when we rework TZIR memory layout, this function will no longer have a possible error.
pub fn resolveInst(sema: *Sema, zir_ref: zir.Inst.Ref) error{OutOfMemory}!*ir.Inst {
    var i: usize = @enumToInt(zir_ref);

    // First section of indexes correspond to a set number of constant values.
    if (i < zir.Inst.Ref.typed_value_map.len) {
        // TODO when we rework TZIR memory layout, this function can be as simple as:
        // if (zir_ref < zir.const_inst_list.len + sema.param_count)
        //     return zir_ref;
        // Until then we allocate memory for a new, mutable `ir.Inst` to match what
        // TZIR expects.
        return sema.mod.constInst(sema.arena, .unneeded, zir.Inst.Ref.typed_value_map[i]);
    }
    i -= zir.Inst.Ref.typed_value_map.len;

    // Next section of indexes correspond to function parameters, if any.
    if (i < sema.param_inst_list.len) {
        return sema.param_inst_list[i];
    }
    i -= sema.param_inst_list.len;

    // Finally, the last section of indexes refers to the map of ZIR=>TZIR.
    return sema.inst_map[i];
}

fn resolveConstString(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    zir_ref: zir.Inst.Ref,
) ![]u8 {
    const tzir_inst = try sema.resolveInst(zir_ref);
    const wanted_type = Type.initTag(.const_slice_u8);
    const coerced_inst = try sema.coerce(block, wanted_type, tzir_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced_inst);
    return val.toAllocatedBytes(sema.arena);
}

fn resolveType(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, zir_ref: zir.Inst.Ref) !Type {
    const tzir_inst = try sema.resolveInst(zir_ref);
    const wanted_type = Type.initTag(.@"type");
    const coerced_inst = try sema.coerce(block, wanted_type, tzir_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced_inst);
    return val.toType(sema.arena);
}

fn resolveConstValue(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, base: *ir.Inst) !Value {
    return (try sema.resolveDefinedValue(block, src, base)) orelse
        return sema.failWithNeededComptime(block, src);
}

fn resolveDefinedValue(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, base: *ir.Inst) !?Value {
    if (base.value()) |val| {
        if (val.isUndef()) {
            return sema.failWithUseOfUndef(block, src);
        }
        return val;
    }
    return null;
}

fn failWithNeededComptime(sema: *Sema, block: *Scope.Block, src: LazySrcLoc) InnerError {
    return sema.mod.fail(&block.base, src, "unable to resolve comptime value", .{});
}

fn failWithUseOfUndef(sema: *Sema, block: *Scope.Block, src: LazySrcLoc) InnerError {
    return sema.mod.fail(&block.base, src, "use of undefined value here causes undefined behavior", .{});
}

/// Appropriate to call when the coercion has already been done by result
/// location semantics. Asserts the value fits in the provided `Int` type.
/// Only supports `Int` types 64 bits or less.
fn resolveAlreadyCoercedInt(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    zir_ref: zir.Inst.Ref,
    comptime Int: type,
) !Int {
    comptime assert(@typeInfo(Int).Int.bits <= 64);
    const tzir_inst = try sema.resolveInst(zir_ref);
    const val = try sema.resolveConstValue(block, src, tzir_inst);
    switch (@typeInfo(Int).Int.signedness) {
        .signed => return @intCast(Int, val.toSignedInt()),
        .unsigned => return @intCast(Int, val.toUnsignedInt()),
    }
}

fn resolveInt(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    zir_ref: zir.Inst.Ref,
    dest_type: Type,
) !u64 {
    const tzir_inst = try sema.resolveInst(zir_ref);
    const coerced = try sema.coerce(block, dest_type, tzir_inst, src);
    const val = try sema.resolveConstValue(block, src, coerced);

    return val.toUnsignedInt();
}

fn resolveInstConst(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    zir_ref: zir.Inst.Ref,
) InnerError!TypedValue {
    const tzir_inst = try sema.resolveInst(zir_ref);
    const val = try sema.resolveConstValue(block, src, tzir_inst);
    return TypedValue{
        .ty = tzir_inst.ty,
        .val = val,
    };
}

fn zirBitcastResultPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zir_sema.zirBitcastResultPtr", .{});
}

fn zirCoerceResultPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirCoerceResultPtr", .{});
}

fn zirStructDecl(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    layout: std.builtin.TypeInfo.ContainerLayout,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = sema.gpa;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.StructDecl, inst_data.payload_index);
    const fields_len = extra.data.fields_len;
    const bit_bags_count = std.math.divCeil(usize, fields_len, 16) catch unreachable;

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    var fields_map: std.StringArrayHashMapUnmanaged(Module.Struct.Field) = .{};
    try fields_map.ensureCapacity(&new_decl_arena.allocator, fields_len);

    {
        var field_index: usize = extra.end + bit_bags_count;
        var bit_bag_index: usize = extra.end;
        var cur_bit_bag: u32 = undefined;
        var field_i: u32 = 0;
        while (field_i < fields_len) : (field_i += 1) {
            if (field_i % 16 == 0) {
                cur_bit_bag = sema.code.extra[bit_bag_index];
                bit_bag_index += 1;
            }
            const has_align = @truncate(u1, cur_bit_bag) != 0;
            cur_bit_bag >>= 1;
            const has_default = @truncate(u1, cur_bit_bag) != 0;
            cur_bit_bag >>= 1;

            const field_name_zir = sema.code.nullTerminatedString(sema.code.extra[field_index]);
            field_index += 1;
            const field_type_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[field_index]);
            field_index += 1;

            // This string needs to outlive the ZIR code.
            const field_name = try new_decl_arena.allocator.dupe(u8, field_name_zir);
            // TODO: if we need to report an error here, use a source location
            // that points to this type expression rather than the struct.
            // But only resolve the source location if we need to emit a compile error.
            const field_ty = try sema.resolveType(block, src, field_type_ref);

            const gop = fields_map.getOrPutAssumeCapacity(field_name);
            assert(!gop.found_existing);
            gop.entry.value = .{
                .ty = field_ty,
                .abi_align = Value.initTag(.abi_align_default),
                .default_val = Value.initTag(.unreachable_value),
            };

            if (has_align) {
                const align_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[field_index]);
                field_index += 1;
                // TODO: if we need to report an error here, use a source location
                // that points to this alignment expression rather than the struct.
                // But only resolve the source location if we need to emit a compile error.
                gop.entry.value.abi_align = (try sema.resolveInstConst(block, src, align_ref)).val;
            }
            if (has_default) {
                const default_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[field_index]);
                field_index += 1;
                // TODO: if we need to report an error here, use a source location
                // that points to this default value expression rather than the struct.
                // But only resolve the source location if we need to emit a compile error.
                gop.entry.value.default_val = (try sema.resolveInstConst(block, src, default_ref)).val;
            }
        }
    }

    const struct_obj = try new_decl_arena.allocator.create(Module.Struct);
    const struct_ty = try Type.Tag.@"struct".create(&new_decl_arena.allocator, struct_obj);
    const struct_val = try Value.Tag.ty.create(&new_decl_arena.allocator, struct_ty);
    const new_decl = try sema.mod.createAnonymousDecl(&block.base, &new_decl_arena, .{
        .ty = Type.initTag(.type),
        .val = struct_val,
    });
    struct_obj.* = .{
        .owner_decl = sema.owner_decl,
        .fields = fields_map,
        .node_offset = inst_data.src_node,
        .container = .{
            .ty = struct_ty,
            .file_scope = block.getFileScope(),
            .parent_name_hash = new_decl.fullyQualifiedNameHash(),
        },
    };
    return sema.analyzeDeclVal(block, src, new_decl);
}

fn zirEnumDecl(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    nonexhaustive: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);

    return sema.mod.fail(&block.base, sema.src, "TODO implement zirEnumDecl", .{});
}

fn zirUnionDecl(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);

    return sema.mod.fail(&block.base, sema.src, "TODO implement zirUnionDecl", .{});
}

fn zirOpaqueDecl(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);

    return sema.mod.fail(&block.base, sema.src, "TODO implement zirOpaqueDecl", .{});
}

fn zirRetPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    try sema.requireFunctionBlock(block, src);
    const fn_ty = sema.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    const ptr_type = try sema.mod.simplePtrType(sema.arena, ret_type, true, .One);
    return block.addNoOp(src, ptr_type, .alloc);
}

fn zirRef(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const operand = try sema.resolveInst(inst_data.operand);
    return sema.analyzeRef(block, inst_data.src(), operand);
}

fn zirRetType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    try sema.requireFunctionBlock(block, src);
    const fn_ty = sema.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    return sema.mod.constType(sema.arena, src, ret_type);
}

fn zirEnsureResultUsed(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = try sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.ensureResultUsed(block, operand, src);
}

fn ensureResultUsed(
    sema: *Sema,
    block: *Scope.Block,
    operand: *Inst,
    src: LazySrcLoc,
) InnerError!void {
    switch (operand.ty.zigTypeTag()) {
        .Void, .NoReturn => return,
        else => return sema.mod.fail(&block.base, src, "expression value is ignored", .{}),
    }
}

fn zirEnsureResultNonError(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = try sema.resolveInst(inst_data.operand);
    const src = inst_data.src();
    switch (operand.ty.zigTypeTag()) {
        .ErrorSet, .ErrorUnion => return sema.mod.fail(&block.base, src, "error is discarded", .{}),
        else => return,
    }
}

fn zirIndexablePtrLen(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const array_ptr = try sema.resolveInst(inst_data.operand);

    const elem_ty = array_ptr.ty.elemType();
    if (!elem_ty.isIndexable()) {
        const cond_src: LazySrcLoc = .{ .node_offset_for_cond = inst_data.src_node };
        const msg = msg: {
            const msg = try sema.mod.errMsg(
                &block.base,
                cond_src,
                "type '{}' does not support indexing",
                .{elem_ty},
            );
            errdefer msg.destroy(sema.gpa);
            try sema.mod.errNote(
                &block.base,
                cond_src,
                msg,
                "for loop operand must be an array, slice, tuple, or vector",
                .{},
            );
            break :msg msg;
        };
        return sema.mod.failWithOwnedErrorMsg(&block.base, msg);
    }
    const result_ptr = try sema.namedFieldPtr(block, src, array_ptr, "len", src);
    return sema.analyzeLoad(block, src, result_ptr, result_ptr.src);
}

fn zirAlloc(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const var_decl_src = inst_data.src();
    const var_type = try sema.resolveType(block, ty_src, inst_data.operand);
    const ptr_type = try sema.mod.simplePtrType(sema.arena, var_type, true, .One);
    try sema.requireRuntimeBlock(block, var_decl_src);
    return block.addNoOp(var_decl_src, ptr_type, .alloc);
}

fn zirAllocMut(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const var_decl_src = inst_data.src();
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const var_type = try sema.resolveType(block, ty_src, inst_data.operand);
    try sema.validateVarType(block, ty_src, var_type);
    const ptr_type = try sema.mod.simplePtrType(sema.arena, var_type, true, .One);
    try sema.requireRuntimeBlock(block, var_decl_src);
    return block.addNoOp(var_decl_src, ptr_type, .alloc);
}

fn zirAllocInferred(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    inferred_alloc_ty: Type,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };

    const val_payload = try sema.arena.create(Value.Payload.InferredAlloc);
    val_payload.* = .{
        .data = .{},
    };
    // `Module.constInst` does not add the instruction to the block because it is
    // not needed in the case of constant values. However here, we plan to "downgrade"
    // to a normal instruction when we hit `resolve_inferred_alloc`. So we append
    // to the block even though it is currently a `.constant`.
    const result = try sema.mod.constInst(sema.arena, src, .{
        .ty = inferred_alloc_ty,
        .val = Value.initPayload(&val_payload.base),
    });
    try sema.requireFunctionBlock(block, src);
    try block.instructions.append(sema.gpa, result);
    return result;
}

fn zirResolveInferredAlloc(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = inst_data.src_node };
    const ptr = try sema.resolveInst(inst_data.operand);
    const ptr_val = ptr.castTag(.constant).?.val;
    const inferred_alloc = ptr_val.castTag(.inferred_alloc).?;
    const peer_inst_list = inferred_alloc.data.stored_inst_list.items;
    const final_elem_ty = try sema.resolvePeerTypes(block, ty_src, peer_inst_list);
    const var_is_mut = switch (ptr.ty.tag()) {
        .inferred_alloc_const => false,
        .inferred_alloc_mut => true,
        else => unreachable,
    };
    if (var_is_mut) {
        try sema.validateVarType(block, ty_src, final_elem_ty);
    }
    const final_ptr_ty = try sema.mod.simplePtrType(sema.arena, final_elem_ty, true, .One);

    // Change it to a normal alloc.
    ptr.ty = final_ptr_ty;
    ptr.tag = .alloc;
}

fn zirValidateStructInitPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = sema.gpa;
    const mod = sema.mod;
    const validate_inst = sema.code.instructions.items(.data)[inst].pl_node;
    const struct_init_src = validate_inst.src();
    const validate_extra = sema.code.extraData(zir.Inst.Block, validate_inst.payload_index);
    const instrs = sema.code.extra[validate_extra.end..][0..validate_extra.data.body_len];

    const struct_obj: *Module.Struct = s: {
        const field_ptr_data = sema.code.instructions.items(.data)[instrs[0]].pl_node;
        const field_ptr_extra = sema.code.extraData(zir.Inst.Field, field_ptr_data.payload_index).data;
        const object_ptr = try sema.resolveInst(field_ptr_extra.lhs);
        break :s object_ptr.ty.elemType().castTag(.@"struct").?.data;
    };

    // Maps field index to field_ptr index of where it was already initialized.
    const found_fields = try gpa.alloc(zir.Inst.Index, struct_obj.fields.entries.items.len);
    defer gpa.free(found_fields);

    mem.set(zir.Inst.Index, found_fields, 0);

    for (instrs) |field_ptr| {
        const field_ptr_data = sema.code.instructions.items(.data)[field_ptr].pl_node;
        const field_src: LazySrcLoc = .{ .node_offset_back2tok = field_ptr_data.src_node };
        const field_ptr_extra = sema.code.extraData(zir.Inst.Field, field_ptr_data.payload_index).data;
        const field_name = sema.code.nullTerminatedString(field_ptr_extra.field_name_start);
        const field_index = struct_obj.fields.getIndex(field_name) orelse
            return sema.failWithBadFieldAccess(block, struct_obj, field_src, field_name);
        if (found_fields[field_index] != 0) {
            const other_field_ptr = found_fields[field_index];
            const other_field_ptr_data = sema.code.instructions.items(.data)[other_field_ptr].pl_node;
            const other_field_src: LazySrcLoc = .{ .node_offset_back2tok = other_field_ptr_data.src_node };
            const msg = msg: {
                const msg = try mod.errMsg(&block.base, field_src, "duplicate field", .{});
                errdefer msg.destroy(gpa);
                try mod.errNote(&block.base, other_field_src, msg, "other field here", .{});
                break :msg msg;
            };
            return mod.failWithOwnedErrorMsg(&block.base, msg);
        }
        found_fields[field_index] = field_ptr;
    }

    var root_msg: ?*Module.ErrorMsg = null;

    for (found_fields) |field_ptr, i| {
        if (field_ptr != 0) continue;

        const field_name = struct_obj.fields.entries.items[i].key;
        const template = "mising struct field: {s}";
        const args = .{field_name};
        if (root_msg) |msg| {
            try mod.errNote(&block.base, struct_init_src, msg, template, args);
        } else {
            root_msg = try mod.errMsg(&block.base, struct_init_src, template, args);
        }
    }
    if (root_msg) |msg| {
        const fqn = try struct_obj.getFullyQualifiedName(gpa);
        defer gpa.free(fqn);
        try mod.errNoteNonLazy(
            struct_obj.srcLoc(),
            msg,
            "struct '{s}' declared here",
            .{fqn},
        );
        return mod.failWithOwnedErrorMsg(&block.base, msg);
    }
}

fn failWithBadFieldAccess(
    sema: *Sema,
    block: *Scope.Block,
    struct_obj: *Module.Struct,
    field_src: LazySrcLoc,
    field_name: []const u8,
) InnerError {
    const mod = sema.mod;
    const gpa = sema.gpa;

    const fqn = try struct_obj.getFullyQualifiedName(gpa);
    defer gpa.free(fqn);

    const msg = msg: {
        const msg = try mod.errMsg(
            &block.base,
            field_src,
            "no field named '{s}' in struct '{s}'",
            .{ field_name, fqn },
        );
        errdefer msg.destroy(gpa);
        try mod.errNoteNonLazy(struct_obj.srcLoc(), msg, "struct declared here", .{});
        break :msg msg;
    };
    return mod.failWithOwnedErrorMsg(&block.base, msg);
}

fn zirStoreToBlockPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const ptr = try sema.resolveInst(bin_inst.lhs);
    const value = try sema.resolveInst(bin_inst.rhs);
    const ptr_ty = try sema.mod.simplePtrType(sema.arena, value.ty, true, .One);
    // TODO detect when this store should be done at compile-time. For example,
    // if expressions should force it when the condition is compile-time known.
    const src: LazySrcLoc = .unneeded;
    try sema.requireRuntimeBlock(block, src);
    const bitcasted_ptr = try block.addUnOp(src, ptr_ty, .bitcast, ptr);
    return sema.storePtr(block, src, bitcasted_ptr, value);
}

fn zirStoreToInferredPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const ptr = try sema.resolveInst(bin_inst.lhs);
    const value = try sema.resolveInst(bin_inst.rhs);
    const inferred_alloc = ptr.castTag(.constant).?.val.castTag(.inferred_alloc).?;
    // Add the stored instruction to the set we will use to resolve peer types
    // for the inferred allocation.
    try inferred_alloc.data.stored_inst_list.append(sema.arena, value);
    // Create a runtime bitcast instruction with exactly the type the pointer wants.
    const ptr_ty = try sema.mod.simplePtrType(sema.arena, value.ty, true, .One);
    try sema.requireRuntimeBlock(block, src);
    const bitcasted_ptr = try block.addUnOp(src, ptr_ty, .bitcast, ptr);
    return sema.storePtr(block, src, bitcasted_ptr, value);
}

fn zirSetEvalBranchQuota(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    try sema.requireFunctionBlock(block, src);
    const quota = try sema.resolveAlreadyCoercedInt(block, src, inst_data.operand, u32);
    if (sema.branch_quota < quota)
        sema.branch_quota = quota;
}

fn zirStore(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const ptr = try sema.resolveInst(bin_inst.lhs);
    const value = try sema.resolveInst(bin_inst.rhs);
    return sema.storePtr(block, sema.src, ptr, value);
}

fn zirStoreNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const ptr = try sema.resolveInst(extra.lhs);
    const value = try sema.resolveInst(extra.rhs);
    return sema.storePtr(block, src, ptr, value);
}

fn zirParamType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    const inst_data = sema.code.instructions.items(.data)[inst].param_type;
    const fn_inst = try sema.resolveInst(inst_data.callee);
    const param_index = inst_data.param_index;

    const fn_ty: Type = switch (fn_inst.ty.zigTypeTag()) {
        .Fn => fn_inst.ty,
        .BoundFn => {
            return sema.mod.fail(&block.base, fn_inst.src, "TODO implement zirParamType for method call syntax", .{});
        },
        else => {
            return sema.mod.fail(&block.base, fn_inst.src, "expected function, found '{}'", .{fn_inst.ty});
        },
    };

    const param_count = fn_ty.fnParamLen();
    if (param_index >= param_count) {
        if (fn_ty.fnIsVarArgs()) {
            return sema.mod.constType(sema.arena, src, Type.initTag(.var_args_param));
        }
        return sema.mod.fail(&block.base, src, "arg index {d} out of bounds; '{}' has {d} argument(s)", .{
            param_index,
            fn_ty,
            param_count,
        });
    }

    // TODO support generic functions
    const param_type = fn_ty.fnParamType(param_index);
    return sema.mod.constType(sema.arena, src, param_type);
}

fn zirStr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_bytes = sema.code.instructions.items(.data)[inst].str.get(sema.code);

    // `zir_bytes` references memory inside the ZIR module, which can get deallocated
    // after semantic analysis is complete, for example in the case of the initialization
    // expression of a variable declaration. We need the memory to be in the new
    // anonymous Decl's arena.

    var new_decl_arena = std.heap.ArenaAllocator.init(sema.gpa);
    errdefer new_decl_arena.deinit();

    const bytes = try new_decl_arena.allocator.dupe(u8, zir_bytes);

    const decl_ty = try Type.Tag.array_u8_sentinel_0.create(&new_decl_arena.allocator, bytes.len);
    const decl_val = try Value.Tag.bytes.create(&new_decl_arena.allocator, bytes);

    const new_decl = try sema.mod.createAnonymousDecl(&block.base, &new_decl_arena, .{
        .ty = decl_ty,
        .val = decl_val,
    });
    return sema.analyzeDeclRef(block, .unneeded, new_decl);
}

fn zirInt(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const int = sema.code.instructions.items(.data)[inst].int;
    return sema.mod.constIntUnsigned(sema.arena, .unneeded, Type.initTag(.comptime_int), int);
}

fn zirFloat(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].float;
    const src = inst_data.src();
    const number = inst_data.number;

    return sema.mod.constInst(arena, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = try Value.Tag.float_32.create(arena, number),
    });
}

fn zirFloat128(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Float128, inst_data.payload_index).data;
    const src = inst_data.src();
    const number = extra.get();

    return sema.mod.constInst(arena, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = try Value.Tag.float_128.create(arena, number),
    });
}

fn zirCompileError(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const msg = try sema.resolveConstString(block, operand_src, inst_data.operand);
    return sema.mod.fail(&block.base, src, "{s}", .{msg});
}

fn zirCompileLog(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    var managed = sema.mod.compile_log_text.toManaged(sema.gpa);
    defer sema.mod.compile_log_text = managed.moveToUnmanaged();
    const writer = managed.writer();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.MultiOp, inst_data.payload_index);
    const args = sema.code.refSlice(extra.end, extra.data.operands_len);

    for (args) |arg_ref, i| {
        if (i != 0) try writer.print(", ", .{});

        const arg = try sema.resolveInst(arg_ref);
        if (arg.value()) |val| {
            try writer.print("@as({}, {})", .{ arg.ty, val });
        } else {
            try writer.print("@as({}, [runtime value])", .{arg.ty});
        }
    }
    try writer.print("\n", .{});

    const gop = try sema.mod.compile_log_decls.getOrPut(sema.gpa, sema.owner_decl);
    if (!gop.found_existing) {
        gop.entry.value = inst_data.src().toSrcLoc(&block.base);
    }
}

fn zirRepeat(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };
    try sema.requireRuntimeBlock(block, src);
    return always_noreturn;
}

fn zirLoop(sema: *Sema, parent_block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];

    // TZIR expects a block outside the loop block too.
    const block_inst = try sema.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = undefined,
            .src = src,
        },
        .body = undefined,
    };

    var child_block = parent_block.makeSubBlock();
    child_block.label = Scope.Block.Label{
        .zir_block = inst,
        .merges = .{
            .results = .{},
            .br_list = .{},
            .block_inst = block_inst,
        },
    };
    const merges = &child_block.label.?.merges;

    defer child_block.instructions.deinit(sema.gpa);
    defer merges.results.deinit(sema.gpa);
    defer merges.br_list.deinit(sema.gpa);

    // Reserve space for a Loop instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const loop_inst = try sema.arena.create(Inst.Loop);
    loop_inst.* = .{
        .base = .{
            .tag = Inst.Loop.base_tag,
            .ty = Type.initTag(.noreturn),
            .src = src,
        },
        .body = undefined,
    };

    var loop_block = child_block.makeSubBlock();
    defer loop_block.instructions.deinit(sema.gpa);

    _ = try sema.analyzeBody(&loop_block, body);

    // Loop repetition is implied so the last instruction may or may not be a noreturn instruction.

    try child_block.instructions.append(sema.gpa, &loop_inst.base);
    loop_inst.body = .{ .instructions = try sema.arena.dupe(*Inst, loop_block.instructions.items) };

    return sema.analyzeBlockBody(parent_block, src, &child_block, merges);
}

fn zirBlock(sema: *Sema, parent_block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];

    // Reserve space for a Block instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const block_inst = try sema.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = undefined, // Set after analysis.
            .src = src,
        },
        .body = undefined,
    };

    var child_block: Scope.Block = .{
        .parent = parent_block,
        .sema = sema,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?Scope.Block.Label, Scope.Block.Label{
            .zir_block = inst,
            .merges = .{
                .results = .{},
                .br_list = .{},
                .block_inst = block_inst,
            },
        }),
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
    };
    const merges = &child_block.label.?.merges;

    defer child_block.instructions.deinit(sema.gpa);
    defer merges.results.deinit(sema.gpa);
    defer merges.br_list.deinit(sema.gpa);

    _ = try sema.analyzeBody(&child_block, body);

    return sema.analyzeBlockBody(parent_block, src, &child_block, merges);
}

fn analyzeBlockBody(
    sema: *Sema,
    parent_block: *Scope.Block,
    src: LazySrcLoc,
    child_block: *Scope.Block,
    merges: *Scope.Block.Merges,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    // Blocks must terminate with noreturn instruction.
    assert(child_block.instructions.items.len != 0);
    assert(child_block.instructions.items[child_block.instructions.items.len - 1].ty.isNoReturn());

    if (merges.results.items.len == 0) {
        // No need for a block instruction. We can put the new instructions
        // directly into the parent block.
        const copied_instructions = try sema.arena.dupe(*Inst, child_block.instructions.items);
        try parent_block.instructions.appendSlice(sema.gpa, copied_instructions);
        return copied_instructions[copied_instructions.len - 1];
    }
    if (merges.results.items.len == 1) {
        const last_inst_index = child_block.instructions.items.len - 1;
        const last_inst = child_block.instructions.items[last_inst_index];
        if (last_inst.breakBlock()) |br_block| {
            if (br_block == merges.block_inst) {
                // No need for a block instruction. We can put the new instructions directly
                // into the parent block. Here we omit the break instruction.
                const copied_instructions = try sema.arena.dupe(*Inst, child_block.instructions.items[0..last_inst_index]);
                try parent_block.instructions.appendSlice(sema.gpa, copied_instructions);
                return merges.results.items[0];
            }
        }
    }
    // It is impossible to have the number of results be > 1 in a comptime scope.
    assert(!child_block.is_comptime); // Should already got a compile error in the condbr condition.

    // Need to set the type and emit the Block instruction. This allows machine code generation
    // to emit a jump instruction to after the block when it encounters the break.
    try parent_block.instructions.append(sema.gpa, &merges.block_inst.base);
    const resolved_ty = try sema.resolvePeerTypes(parent_block, src, merges.results.items);
    merges.block_inst.base.ty = resolved_ty;
    merges.block_inst.body = .{
        .instructions = try sema.arena.dupe(*Inst, child_block.instructions.items),
    };
    // Now that the block has its type resolved, we need to go back into all the break
    // instructions, and insert type coercion on the operands.
    for (merges.br_list.items) |br| {
        if (br.operand.ty.eql(resolved_ty)) {
            // No type coercion needed.
            continue;
        }
        var coerce_block = parent_block.makeSubBlock();
        defer coerce_block.instructions.deinit(sema.gpa);
        const coerced_operand = try sema.coerce(&coerce_block, resolved_ty, br.operand, br.operand.src);
        // If no instructions were produced, such as in the case of a coercion of a
        // constant value to a new type, we can simply point the br operand to it.
        if (coerce_block.instructions.items.len == 0) {
            br.operand = coerced_operand;
            continue;
        }
        assert(coerce_block.instructions.items[coerce_block.instructions.items.len - 1] == coerced_operand);
        // Here we depend on the br instruction having been over-allocated (if necessary)
        // inside zirBreak so that it can be converted into a br_block_flat instruction.
        const br_src = br.base.src;
        const br_ty = br.base.ty;
        const br_block_flat = @ptrCast(*Inst.BrBlockFlat, br);
        br_block_flat.* = .{
            .base = .{
                .src = br_src,
                .ty = br_ty,
                .tag = .br_block_flat,
            },
            .block = merges.block_inst,
            .body = .{
                .instructions = try sema.arena.dupe(*Inst, coerce_block.instructions.items),
            },
        };
    }
    return &merges.block_inst.base;
}

fn zirExport(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };

    // TODO (see corresponding TODO in AstGen) this is supposed to be a `decl_ref`
    // instruction, which could reference any decl, which is then supposed to get
    // exported, regardless of whether or not it is a function.
    const target_fn = try sema.resolveInstConst(block, lhs_src, extra.lhs);
    // TODO (see corresponding TODO in AstGen) this is supposed to be
    // `std.builtin.ExportOptions`, not a string.
    const export_name = try sema.resolveConstString(block, rhs_src, extra.rhs);

    const actual_fn = target_fn.val.castTag(.function).?.data;
    try sema.mod.analyzeExport(&block.base, src, export_name, actual_fn.owner_decl);
}

fn zirBreakpoint(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };
    try sema.requireRuntimeBlock(block, src);
    _ = try block.addNoOp(src, Type.initTag(.void), .breakpoint);
}

fn zirBreak(sema: *Sema, start_block: *Scope.Block, inst: zir.Inst.Index) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].@"break";
    const src = sema.src;
    const operand = try sema.resolveInst(inst_data.operand);
    const zir_block = inst_data.block_inst;

    var block = start_block;
    while (true) {
        if (block.label) |*label| {
            if (label.zir_block == zir_block) {
                // Here we add a br instruction, but we over-allocate a little bit
                // (if necessary) to make it possible to convert the instruction into
                // a br_block_flat instruction later.
                const br = @ptrCast(*Inst.Br, try sema.arena.alignedAlloc(
                    u8,
                    Inst.convertable_br_align,
                    Inst.convertable_br_size,
                ));
                br.* = .{
                    .base = .{
                        .tag = .br,
                        .ty = Type.initTag(.noreturn),
                        .src = src,
                    },
                    .operand = operand,
                    .block = label.merges.block_inst,
                };
                try start_block.instructions.append(sema.gpa, &br.base);
                try label.merges.results.append(sema.gpa, operand);
                try label.merges.br_list.append(sema.gpa, br);
                return inst;
            }
        }
        block = block.parent.?;
    }
}

fn zirDbgStmtNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    // We do not set sema.src here because dbg_stmt instructions are only emitted for
    // ZIR code that possibly will need to generate runtime code. So error messages
    // and other source locations must not rely on sema.src being set from dbg_stmt
    // instructions.
    if (block.is_comptime) return;

    const src_node = sema.code.instructions.items(.data)[inst].node;
    const src: LazySrcLoc = .{ .node_offset = src_node };

    const src_loc = src.toSrcLoc(&block.base);
    const abs_byte_off = try src_loc.byteOffset();
    _ = try block.addDbgStmt(src, abs_byte_off);
}

fn zirDeclRef(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const decl = sema.owner_decl.dependencies.entries.items[inst_data.payload_index].key;
    return sema.analyzeDeclRef(block, src, decl);
}

fn zirDeclVal(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const decl = sema.owner_decl.dependencies.entries.items[inst_data.payload_index].key;
    return sema.analyzeDeclVal(block, src, decl);
}

fn zirCallNone(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    ensure_result_used: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const func_src: LazySrcLoc = .{ .node_offset_call_func = inst_data.src_node };

    return sema.analyzeCall(block, inst_data.operand, func_src, inst_data.src(), .auto, ensure_result_used, &.{});
}

fn zirCall(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    modifier: std.builtin.CallOptions.Modifier,
    ensure_result_used: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const func_src: LazySrcLoc = .{ .node_offset_call_func = inst_data.src_node };
    const call_src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.Call, inst_data.payload_index);
    const args = sema.code.refSlice(extra.end, extra.data.args_len);

    return sema.analyzeCall(block, extra.data.callee, func_src, call_src, modifier, ensure_result_used, args);
}

fn analyzeCall(
    sema: *Sema,
    block: *Scope.Block,
    zir_func: zir.Inst.Ref,
    func_src: LazySrcLoc,
    call_src: LazySrcLoc,
    modifier: std.builtin.CallOptions.Modifier,
    ensure_result_used: bool,
    zir_args: []const zir.Inst.Ref,
) InnerError!*ir.Inst {
    const func = try sema.resolveInst(zir_func);

    if (func.ty.zigTypeTag() != .Fn)
        return sema.mod.fail(&block.base, func_src, "type '{}' not a function", .{func.ty});

    const cc = func.ty.fnCallingConvention();
    if (cc == .Naked) {
        // TODO add error note: declared here
        return sema.mod.fail(
            &block.base,
            func_src,
            "unable to call function with naked calling convention",
            .{},
        );
    }
    const fn_params_len = func.ty.fnParamLen();
    if (func.ty.fnIsVarArgs()) {
        assert(cc == .C);
        if (zir_args.len < fn_params_len) {
            // TODO add error note: declared here
            return sema.mod.fail(
                &block.base,
                func_src,
                "expected at least {d} argument(s), found {d}",
                .{ fn_params_len, zir_args.len },
            );
        }
    } else if (fn_params_len != zir_args.len) {
        // TODO add error note: declared here
        return sema.mod.fail(
            &block.base,
            func_src,
            "expected {d} argument(s), found {d}",
            .{ fn_params_len, zir_args.len },
        );
    }

    if (modifier == .compile_time) {
        return sema.mod.fail(&block.base, call_src, "TODO implement comptime function calls", .{});
    }
    if (modifier != .auto) {
        return sema.mod.fail(&block.base, call_src, "TODO implement call with modifier {}", .{modifier});
    }

    // TODO handle function calls of generic functions
    const casted_args = try sema.arena.alloc(*Inst, zir_args.len);
    for (zir_args) |zir_arg, i| {
        // the args are already casted to the result of a param type instruction.
        casted_args[i] = try sema.resolveInst(zir_arg);
    }

    const ret_type = func.ty.fnReturnType();

    const is_comptime_call = block.is_comptime or modifier == .compile_time;
    const is_inline_call = is_comptime_call or modifier == .always_inline or
        func.ty.fnCallingConvention() == .Inline;
    const result: *Inst = if (is_inline_call) res: {
        const func_val = try sema.resolveConstValue(block, func_src, func);
        const module_fn = switch (func_val.tag()) {
            .function => func_val.castTag(.function).?.data,
            .extern_fn => return sema.mod.fail(&block.base, call_src, "{s} call of extern function", .{
                @as([]const u8, if (is_comptime_call) "comptime" else "inline"),
            }),
            else => unreachable,
        };

        // Analyze the ZIR. The same ZIR gets analyzed into a runtime function
        // or an inlined call depending on what union tag the `label` field is
        // set to in the `Scope.Block`.
        // This block instruction will be used to capture the return value from the
        // inlined function.
        const block_inst = try sema.arena.create(Inst.Block);
        block_inst.* = .{
            .base = .{
                .tag = Inst.Block.base_tag,
                .ty = ret_type,
                .src = call_src,
            },
            .body = undefined,
        };
        // This one is shared among sub-blocks within the same callee, but not
        // shared among the entire inline/comptime call stack.
        var inlining: Scope.Block.Inlining = .{
            .merges = .{
                .results = .{},
                .br_list = .{},
                .block_inst = block_inst,
            },
        };
        var inline_sema: Sema = .{
            .mod = sema.mod,
            .gpa = sema.mod.gpa,
            .arena = sema.arena,
            .code = module_fn.zir,
            .inst_map = try sema.gpa.alloc(*ir.Inst, module_fn.zir.instructions.len),
            .owner_decl = sema.owner_decl,
            .owner_func = sema.owner_func,
            .func = module_fn,
            .param_inst_list = casted_args,
            .branch_quota = sema.branch_quota,
            .branch_count = sema.branch_count,
        };
        defer sema.gpa.free(inline_sema.inst_map);

        var child_block: Scope.Block = .{
            .parent = null,
            .sema = &inline_sema,
            .src_decl = module_fn.owner_decl,
            .instructions = .{},
            .label = null,
            .inlining = &inlining,
            .is_comptime = is_comptime_call,
        };

        const merges = &child_block.inlining.?.merges;

        defer child_block.instructions.deinit(sema.gpa);
        defer merges.results.deinit(sema.gpa);
        defer merges.br_list.deinit(sema.gpa);

        try inline_sema.emitBackwardBranch(&child_block, call_src);

        // This will have return instructions analyzed as break instructions to
        // the block_inst above.
        _ = try inline_sema.root(&child_block);

        const result = try inline_sema.analyzeBlockBody(block, call_src, &child_block, merges);

        sema.branch_quota = inline_sema.branch_quota;
        sema.branch_count = inline_sema.branch_count;

        break :res result;
    } else res: {
        try sema.requireRuntimeBlock(block, call_src);
        break :res try block.addCall(call_src, ret_type, func, casted_args);
    };

    if (ensure_result_used) {
        try sema.ensureResultUsed(block, result, call_src);
    }
    return result;
}

fn zirIntType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const int_type = sema.code.instructions.items(.data)[inst].int_type;
    const src = int_type.src();
    const ty = try Module.makeIntType(sema.arena, int_type.signedness, int_type.bit_count);

    return sema.mod.constType(sema.arena, src, ty);
}

fn zirOptionalType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const child_type = try sema.resolveType(block, src, inst_data.operand);
    const opt_type = try sema.mod.optionalType(sema.arena, child_type);

    return sema.mod.constType(sema.arena, src, opt_type);
}

fn zirOptionalTypeFromPtrElem(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ptr = try sema.resolveInst(inst_data.operand);
    const elem_ty = ptr.ty.elemType();
    const opt_ty = try sema.mod.optionalType(sema.arena, elem_ty);

    return sema.mod.constType(sema.arena, inst_data.src(), opt_ty);
}

fn zirArrayType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    // TODO these should be lazily evaluated
    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const len = try sema.resolveInstConst(block, .unneeded, bin_inst.lhs);
    const elem_type = try sema.resolveType(block, .unneeded, bin_inst.rhs);
    const array_ty = try sema.mod.arrayType(sema.arena, len.val.toUnsignedInt(), null, elem_type);

    return sema.mod.constType(sema.arena, .unneeded, array_ty);
}

fn zirArrayTypeSentinel(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    // TODO these should be lazily evaluated
    const inst_data = sema.code.instructions.items(.data)[inst].array_type_sentinel;
    const len = try sema.resolveInstConst(block, .unneeded, inst_data.len);
    const extra = sema.code.extraData(zir.Inst.ArrayTypeSentinel, inst_data.payload_index).data;
    const sentinel = try sema.resolveInstConst(block, .unneeded, extra.sentinel);
    const elem_type = try sema.resolveType(block, .unneeded, extra.elem_type);
    const array_ty = try sema.mod.arrayType(sema.arena, len.val.toUnsignedInt(), sentinel.val, elem_type);

    return sema.mod.constType(sema.arena, .unneeded, array_ty);
}

fn zirErrorUnionType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const error_union = try sema.resolveType(block, lhs_src, extra.lhs);
    const payload = try sema.resolveType(block, rhs_src, extra.rhs);

    if (error_union.zigTypeTag() != .ErrorSet) {
        return sema.mod.fail(&block.base, lhs_src, "expected error set type, found {}", .{
            error_union.elemType(),
        });
    }
    const err_union_ty = try sema.mod.errorUnionType(sema.arena, error_union, payload);
    return sema.mod.constType(sema.arena, src, err_union_ty);
}

fn zirErrorValue(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const src = inst_data.src();

    // Create an anonymous error set type with only this error value, and return the value.
    const entry = try sema.mod.getErrorValue(inst_data.get(sema.code));
    const result_type = try Type.Tag.error_set_single.create(sema.arena, entry.key);
    return sema.mod.constInst(sema.arena, src, .{
        .ty = result_type,
        .val = try Value.Tag.@"error".create(sema.arena, .{
            .name = entry.key,
        }),
    });
}

fn zirErrorToInt(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const op = try sema.resolveInst(inst_data.operand);
    const op_coerced = try sema.coerce(block, Type.initTag(.anyerror), op, operand_src);

    if (op_coerced.value()) |val| {
        const payload = try sema.arena.create(Value.Payload.U64);
        payload.* = .{
            .base = .{ .tag = .int_u64 },
            .data = (try sema.mod.getErrorValue(val.castTag(.@"error").?.data.name)).value,
        };
        return sema.mod.constInst(sema.arena, src, .{
            .ty = Type.initTag(.u16),
            .val = Value.initPayload(&payload.base),
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, Type.initTag(.u16), .error_to_int, op_coerced);
}

fn zirIntToError(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };

    const op = try sema.resolveInst(inst_data.operand);

    if (try sema.resolveDefinedValue(block, operand_src, op)) |value| {
        const int = value.toUnsignedInt();
        if (int > sema.mod.global_error_set.count() or int == 0)
            return sema.mod.fail(&block.base, operand_src, "integer value {d} represents no error", .{int});
        const payload = try sema.arena.create(Value.Payload.Error);
        payload.* = .{
            .base = .{ .tag = .@"error" },
            .data = .{ .name = sema.mod.error_name_list.items[int] },
        };
        return sema.mod.constInst(sema.arena, src, .{
            .ty = Type.initTag(.anyerror),
            .val = Value.initPayload(&payload.base),
        });
    }
    try sema.requireRuntimeBlock(block, src);
    if (block.wantSafety()) {
        return sema.mod.fail(&block.base, src, "TODO: get max errors in compilation", .{});
        // const is_gt_max = @panic("TODO get max errors in compilation");
        // try sema.addSafetyCheck(block, is_gt_max, .invalid_error_code);
    }
    return block.addUnOp(src, Type.initTag(.anyerror), .int_to_error, op);
}

fn zirMergeErrorSets(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs_ty = try sema.resolveType(block, lhs_src, extra.lhs);
    const rhs_ty = try sema.resolveType(block, rhs_src, extra.rhs);
    if (rhs_ty.zigTypeTag() != .ErrorSet)
        return sema.mod.fail(&block.base, rhs_src, "expected error set type, found {}", .{rhs_ty});
    if (lhs_ty.zigTypeTag() != .ErrorSet)
        return sema.mod.fail(&block.base, lhs_src, "expected error set type, found {}", .{lhs_ty});

    // Anything merged with anyerror is anyerror.
    if (lhs_ty.tag() == .anyerror or rhs_ty.tag() == .anyerror) {
        return sema.mod.constInst(sema.arena, src, .{
            .ty = Type.initTag(.type),
            .val = Value.initTag(.anyerror_type),
        });
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
            try set.ensureCapacity(sema.gpa, set.count() + lhs_set.names_len);
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
            try set.ensureCapacity(sema.gpa, set.count() + rhs_set.names_len);
            for (rhs_set.names_ptr[0..rhs_set.names_len]) |name| {
                set.putAssumeCapacity(name, {});
            }
        },
        else => unreachable,
    }

    const new_names = try sema.arena.alloc([]const u8, set.count());
    var it = set.iterator();
    var i: usize = 0;
    while (it.next()) |entry| : (i += 1) {
        new_names[i] = entry.key;
    }

    const new_error_set = try sema.arena.create(Module.ErrorSet);
    new_error_set.* = .{
        .owner_decl = sema.owner_decl,
        .node_offset = inst_data.src_node,
        .names_ptr = new_names.ptr,
        .names_len = @intCast(u32, new_names.len),
    };
    const error_set_ty = try Type.Tag.error_set.create(sema.arena, new_error_set);
    return sema.mod.constInst(sema.arena, src, .{
        .ty = Type.initTag(.type),
        .val = try Value.Tag.ty.create(sema.arena, error_set_ty),
    });
}

fn zirEnumLiteral(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].str_tok;
    const src = inst_data.src();
    const duped_name = try sema.arena.dupe(u8, inst_data.get(sema.code));
    return sema.mod.constInst(sema.arena, src, .{
        .ty = Type.initTag(.enum_literal),
        .val = try Value.Tag.enum_literal.create(sema.arena, duped_name),
    });
}

fn zirEnumLiteralSmall(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const name = sema.code.instructions.items(.data)[inst].small_str.get();
    const src: LazySrcLoc = .unneeded;
    const duped_name = try sema.arena.dupe(u8, name);
    return sema.mod.constInst(sema.arena, src, .{
        .ty = Type.initTag(.enum_literal),
        .val = try Value.Tag.enum_literal.create(sema.arena, duped_name),
    });
}

fn zirEnumToInt(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const mod = sema.mod;
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand = try sema.resolveInst(inst_data.operand);

    const enum_tag: *Inst = switch (operand.ty.zigTypeTag()) {
        .Enum => operand,
        .Union => {
            //if (!operand.ty.unionHasTag()) {
            //    return mod.fail(
            //        &block.base,
            //        operand_src,
            //        "untagged union '{}' cannot be converted to integer",
            //        .{dest_ty_src},
            //    );
            //}
            return mod.fail(&block.base, operand_src, "TODO zirEnumToInt for tagged unions", .{});
        },
        else => {
            return mod.fail(&block.base, operand_src, "expected enum or tagged union, found {}", .{
                operand.ty,
            });
        },
    };

    var int_tag_type_buffer: Type.Payload.Bits = undefined;
    const int_tag_ty = try enum_tag.ty.intTagType(&int_tag_type_buffer).copy(arena);

    if (enum_tag.ty.onePossibleValue()) |opv| {
        return mod.constInst(arena, src, .{
            .ty = int_tag_ty,
            .val = opv,
        });
    }

    if (enum_tag.value()) |enum_tag_val| {
        if (enum_tag_val.castTag(.enum_field_index)) |enum_field_payload| {
            const field_index = enum_field_payload.data;
            switch (enum_tag.ty.tag()) {
                .enum_full => {
                    const enum_full = enum_tag.ty.castTag(.enum_full).?.data;
                    if (enum_full.values.count() != 0) {
                        const val = enum_full.values.entries.items[field_index].key;
                        return mod.constInst(arena, src, .{
                            .ty = int_tag_ty,
                            .val = val,
                        });
                    } else {
                        // Field index and integer values are the same.
                        const val = try Value.Tag.int_u64.create(arena, field_index);
                        return mod.constInst(arena, src, .{
                            .ty = int_tag_ty,
                            .val = val,
                        });
                    }
                },
                .enum_simple => {
                    // Field index and integer values are the same.
                    const val = try Value.Tag.int_u64.create(arena, field_index);
                    return mod.constInst(arena, src, .{
                        .ty = int_tag_ty,
                        .val = val,
                    });
                },
                else => unreachable,
            }
        } else {
            // Assume it is already an integer and return it directly.
            return mod.constInst(arena, src, .{
                .ty = int_tag_ty,
                .val = enum_tag_val,
            });
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, int_tag_ty, .bitcast, enum_tag);
}

fn zirIntToEnum(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const mod = sema.mod;
    const target = mod.getTarget();
    const arena = sema.arena;
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const dest_ty = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = try sema.resolveInst(extra.rhs);

    if (dest_ty.zigTypeTag() != .Enum) {
        return mod.fail(&block.base, dest_ty_src, "expected enum, found {}", .{dest_ty});
    }

    if (dest_ty.isNonexhaustiveEnum()) {
        if (operand.value()) |int_val| {
            return mod.constInst(arena, src, .{
                .ty = dest_ty,
                .val = int_val,
            });
        }
    }

    if (try sema.resolveDefinedValue(block, operand_src, operand)) |int_val| {
        if (!dest_ty.enumHasInt(int_val, target)) {
            const msg = msg: {
                const msg = try mod.errMsg(
                    &block.base,
                    src,
                    "enum '{}' has no tag with value {}",
                    .{ dest_ty, int_val },
                );
                errdefer msg.destroy(sema.gpa);
                try mod.errNoteNonLazy(
                    dest_ty.declSrcLoc(),
                    msg,
                    "enum declared here",
                    .{},
                );
                break :msg msg;
            };
            return mod.failWithOwnedErrorMsg(&block.base, msg);
        }
        return mod.constInst(arena, src, .{
            .ty = dest_ty,
            .val = int_val,
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, dest_ty, .bitcast, operand);
}

/// Pointer in, pointer out.
fn zirOptionalPayloadPtr(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const optional_ptr = try sema.resolveInst(inst_data.operand);
    assert(optional_ptr.ty.zigTypeTag() == .Pointer);
    const src = inst_data.src();

    const opt_type = optional_ptr.ty.elemType();
    if (opt_type.zigTypeTag() != .Optional) {
        return sema.mod.fail(&block.base, src, "expected optional type, found {}", .{opt_type});
    }

    const child_type = try opt_type.optionalChildAlloc(sema.arena);
    const child_pointer = try sema.mod.simplePtrType(sema.arena, child_type, !optional_ptr.ty.isConstPtr(), .One);

    if (optional_ptr.value()) |pointer_val| {
        const val = try pointer_val.pointerDeref(sema.arena);
        if (val.isNull()) {
            return sema.mod.fail(&block.base, src, "unable to unwrap null", .{});
        }
        // The same Value represents the pointer to the optional and the payload.
        return sema.mod.constInst(sema.arena, src, .{
            .ty = child_pointer,
            .val = pointer_val,
        });
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_null = try block.addUnOp(src, Type.initTag(.bool), .is_non_null_ptr, optional_ptr);
        try sema.addSafetyCheck(block, is_non_null, .unwrap_null);
    }
    return block.addUnOp(src, child_pointer, .optional_payload_ptr, optional_ptr);
}

/// Value in, value out.
fn zirOptionalPayload(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    const opt_type = operand.ty;
    if (opt_type.zigTypeTag() != .Optional) {
        return sema.mod.fail(&block.base, src, "expected optional type, found {}", .{opt_type});
    }

    const child_type = try opt_type.optionalChildAlloc(sema.arena);

    if (operand.value()) |val| {
        if (val.isNull()) {
            return sema.mod.fail(&block.base, src, "unable to unwrap null", .{});
        }
        return sema.mod.constInst(sema.arena, src, .{
            .ty = child_type,
            .val = val,
        });
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_null = try block.addUnOp(src, Type.initTag(.bool), .is_non_null, operand);
        try sema.addSafetyCheck(block, is_non_null, .unwrap_null);
    }
    return block.addUnOp(src, child_type, .optional_payload, operand);
}

/// Value in, value out
fn zirErrUnionPayload(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    if (operand.ty.zigTypeTag() != .ErrorUnion)
        return sema.mod.fail(&block.base, operand.src, "expected error union type, found '{}'", .{operand.ty});

    if (operand.value()) |val| {
        if (val.getError()) |name| {
            return sema.mod.fail(&block.base, src, "caught unexpected error '{s}'", .{name});
        }
        const data = val.castTag(.error_union).?.data;
        return sema.mod.constInst(sema.arena, src, .{
            .ty = operand.ty.castTag(.error_union).?.data.payload,
            .val = data,
        });
    }
    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_err = try block.addUnOp(src, Type.initTag(.bool), .is_err, operand);
        try sema.addSafetyCheck(block, is_non_err, .unwrap_errunion);
    }
    return block.addUnOp(src, operand.ty.castTag(.error_union).?.data.payload, .unwrap_errunion_payload, operand);
}

/// Pointer in, pointer out.
fn zirErrUnionPayloadPtr(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    assert(operand.ty.zigTypeTag() == .Pointer);

    if (operand.ty.elemType().zigTypeTag() != .ErrorUnion)
        return sema.mod.fail(&block.base, src, "expected error union type, found {}", .{operand.ty.elemType()});

    const operand_pointer_ty = try sema.mod.simplePtrType(sema.arena, operand.ty.elemType().castTag(.error_union).?.data.payload, !operand.ty.isConstPtr(), .One);

    if (operand.value()) |pointer_val| {
        const val = try pointer_val.pointerDeref(sema.arena);
        if (val.getError()) |name| {
            return sema.mod.fail(&block.base, src, "caught unexpected error '{s}'", .{name});
        }
        const data = val.castTag(.error_union).?.data;
        // The same Value represents the pointer to the error union and the payload.
        return sema.mod.constInst(sema.arena, src, .{
            .ty = operand_pointer_ty,
            .val = try Value.Tag.ref_val.create(
                sema.arena,
                data,
            ),
        });
    }

    try sema.requireRuntimeBlock(block, src);
    if (safety_check and block.wantSafety()) {
        const is_non_err = try block.addUnOp(src, Type.initTag(.bool), .is_err, operand);
        try sema.addSafetyCheck(block, is_non_err, .unwrap_errunion);
    }
    return block.addUnOp(src, operand_pointer_ty, .unwrap_errunion_payload_ptr, operand);
}

/// Value in, value out
fn zirErrUnionCode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    if (operand.ty.zigTypeTag() != .ErrorUnion)
        return sema.mod.fail(&block.base, src, "expected error union type, found '{}'", .{operand.ty});

    if (operand.value()) |val| {
        assert(val.getError() != null);
        const data = val.castTag(.error_union).?.data;
        return sema.mod.constInst(sema.arena, src, .{
            .ty = operand.ty.castTag(.error_union).?.data.error_set,
            .val = data,
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, operand.ty.castTag(.error_union).?.data.payload, .unwrap_errunion_err, operand);
}

/// Pointer in, value out
fn zirErrUnionCodePtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    assert(operand.ty.zigTypeTag() == .Pointer);

    if (operand.ty.elemType().zigTypeTag() != .ErrorUnion)
        return sema.mod.fail(&block.base, src, "expected error union type, found {}", .{operand.ty.elemType()});

    if (operand.value()) |pointer_val| {
        const val = try pointer_val.pointerDeref(sema.arena);
        assert(val.getError() != null);
        const data = val.castTag(.error_union).?.data;
        return sema.mod.constInst(sema.arena, src, .{
            .ty = operand.ty.elemType().castTag(.error_union).?.data.error_set,
            .val = data,
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, operand.ty.castTag(.error_union).?.data.payload, .unwrap_errunion_err_ptr, operand);
}

fn zirEnsureErrPayloadVoid(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    if (operand.ty.zigTypeTag() != .ErrorUnion)
        return sema.mod.fail(&block.base, src, "expected error union type, found '{}'", .{operand.ty});
    if (operand.ty.castTag(.error_union).?.data.payload.zigTypeTag() != .Void) {
        return sema.mod.fail(&block.base, src, "expression value is ignored", .{});
    }
}

fn zirFnType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index, var_args: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.FnType, inst_data.payload_index);
    const param_types = sema.code.refSlice(extra.end, extra.data.param_types_len);

    return sema.fnTypeCommon(
        block,
        inst_data.src_node,
        param_types,
        extra.data.return_type,
        .Unspecified,
        var_args,
    );
}

fn zirFnTypeCc(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index, var_args: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const cc_src: LazySrcLoc = .{ .node_offset_fn_type_cc = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.FnTypeCc, inst_data.payload_index);
    const param_types = sema.code.refSlice(extra.end, extra.data.param_types_len);

    const cc_tv = try sema.resolveInstConst(block, cc_src, extra.data.cc);
    // TODO once we're capable of importing and analyzing decls from
    // std.builtin, this needs to change
    const cc_str = cc_tv.val.castTag(.enum_literal).?.data;
    const cc = std.meta.stringToEnum(std.builtin.CallingConvention, cc_str) orelse
        return sema.mod.fail(&block.base, cc_src, "Unknown calling convention {s}", .{cc_str});
    return sema.fnTypeCommon(
        block,
        inst_data.src_node,
        param_types,
        extra.data.return_type,
        cc,
        var_args,
    );
}

fn fnTypeCommon(
    sema: *Sema,
    block: *Scope.Block,
    src_node_offset: i32,
    zir_param_types: []const zir.Inst.Ref,
    zir_return_type: zir.Inst.Ref,
    cc: std.builtin.CallingConvention,
    var_args: bool,
) InnerError!*Inst {
    const src: LazySrcLoc = .{ .node_offset = src_node_offset };
    const ret_ty_src: LazySrcLoc = .{ .node_offset_fn_type_ret_ty = src_node_offset };
    const return_type = try sema.resolveType(block, ret_ty_src, zir_return_type);

    // Hot path for some common function types.
    if (zir_param_types.len == 0 and !var_args) {
        if (return_type.zigTypeTag() == .NoReturn and cc == .Unspecified) {
            return sema.mod.constType(sema.arena, src, Type.initTag(.fn_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and cc == .Unspecified) {
            return sema.mod.constType(sema.arena, src, Type.initTag(.fn_void_no_args));
        }

        if (return_type.zigTypeTag() == .NoReturn and cc == .Naked) {
            return sema.mod.constType(sema.arena, src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and cc == .C) {
            return sema.mod.constType(sema.arena, src, Type.initTag(.fn_ccc_void_no_args));
        }
    }

    const param_types = try sema.arena.alloc(Type, zir_param_types.len);
    for (zir_param_types) |param_type, i| {
        // TODO make a compile error from `resolveType` report the source location
        // of the specific parameter. Will need to take a similar strategy as
        // `resolveSwitchItemVal` to avoid resolving the source location unless
        // we actually need to report an error.
        param_types[i] = try sema.resolveType(block, src, param_type);
    }

    const fn_ty = try Type.Tag.function.create(sema.arena, .{
        .param_types = param_types,
        .return_type = return_type,
        .cc = cc,
        .is_var_args = var_args,
    });
    return sema.mod.constType(sema.arena, src, fn_ty);
}

fn zirAs(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    return sema.analyzeAs(block, .unneeded, bin_inst.lhs, bin_inst.rhs);
}

fn zirAsNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.As, inst_data.payload_index).data;
    return sema.analyzeAs(block, src, extra.dest_type, extra.operand);
}

fn analyzeAs(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    zir_dest_type: zir.Inst.Ref,
    zir_operand: zir.Inst.Ref,
) InnerError!*Inst {
    const dest_type = try sema.resolveType(block, src, zir_dest_type);
    const operand = try sema.resolveInst(zir_operand);
    return sema.coerce(block, dest_type, operand, src);
}

fn zirPtrtoint(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const ptr = try sema.resolveInst(inst_data.operand);
    if (ptr.ty.zigTypeTag() != .Pointer) {
        const ptr_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
        return sema.mod.fail(&block.base, ptr_src, "expected pointer, found '{}'", .{ptr.ty});
    }
    // TODO handle known-pointer-address
    const src = inst_data.src();
    try sema.requireRuntimeBlock(block, src);
    const ty = Type.initTag(.usize);
    return block.addUnOp(src, ty, .ptrtoint, ptr);
}

fn zirFieldVal(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_field_name = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Field, inst_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(extra.field_name_start);
    const object = try sema.resolveInst(extra.lhs);
    const object_ptr = if (object.ty.zigTypeTag() == .Pointer)
        object
    else
        try sema.analyzeRef(block, src, object);
    const result_ptr = try sema.namedFieldPtr(block, src, object_ptr, field_name, field_name_src);
    return sema.analyzeLoad(block, src, result_ptr, result_ptr.src);
}

fn zirFieldPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_field_name = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Field, inst_data.payload_index).data;
    const field_name = sema.code.nullTerminatedString(extra.field_name_start);
    const object_ptr = try sema.resolveInst(extra.lhs);
    return sema.namedFieldPtr(block, src, object_ptr, field_name, field_name_src);
}

fn zirFieldValNamed(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.FieldNamed, inst_data.payload_index).data;
    const object = try sema.resolveInst(extra.lhs);
    const field_name = try sema.resolveConstString(block, field_name_src, extra.field_name);
    const object_ptr = try sema.analyzeRef(block, src, object);
    const result_ptr = try sema.namedFieldPtr(block, src, object_ptr, field_name, field_name_src);
    return sema.analyzeLoad(block, src, result_ptr, src);
}

fn zirFieldPtrNamed(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const field_name_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.FieldNamed, inst_data.payload_index).data;
    const object_ptr = try sema.resolveInst(extra.lhs);
    const field_name = try sema.resolveConstString(block, field_name_src, extra.field_name);
    return sema.namedFieldPtr(block, src, object_ptr, field_name, field_name_src);
}

fn zirIntcast(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;

    const dest_type = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = try sema.resolveInst(extra.rhs);

    const dest_is_comptime_int = switch (dest_type.zigTypeTag()) {
        .ComptimeInt => true,
        .Int => false,
        else => return sema.mod.fail(
            &block.base,
            dest_ty_src,
            "expected integer type, found '{}'",
            .{dest_type},
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeInt, .Int => {},
        else => return sema.mod.fail(
            &block.base,
            operand_src,
            "expected integer type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return sema.coerce(block, dest_type, operand, operand_src);
    } else if (dest_is_comptime_int) {
        return sema.mod.fail(&block.base, src, "unable to cast runtime value to 'comptime_int'", .{});
    }

    return sema.mod.fail(&block.base, src, "TODO implement analyze widen or shorten int", .{});
}

fn zirBitcast(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;

    const dest_type = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = try sema.resolveInst(extra.rhs);
    return sema.bitcast(block, dest_type, operand);
}

fn zirFloatcast(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const dest_ty_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;

    const dest_type = try sema.resolveType(block, dest_ty_src, extra.lhs);
    const operand = try sema.resolveInst(extra.rhs);

    const dest_is_comptime_float = switch (dest_type.zigTypeTag()) {
        .ComptimeFloat => true,
        .Float => false,
        else => return sema.mod.fail(
            &block.base,
            dest_ty_src,
            "expected float type, found '{}'",
            .{dest_type},
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeFloat, .Float, .ComptimeInt => {},
        else => return sema.mod.fail(
            &block.base,
            operand_src,
            "expected float type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return sema.coerce(block, dest_type, operand, operand_src);
    } else if (dest_is_comptime_float) {
        return sema.mod.fail(&block.base, src, "unable to cast runtime value to 'comptime_float'", .{});
    }

    return sema.mod.fail(&block.base, src, "TODO implement analyze widen or shorten float", .{});
}

fn zirElemVal(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const array = try sema.resolveInst(bin_inst.lhs);
    const array_ptr = if (array.ty.zigTypeTag() == .Pointer)
        array
    else
        try sema.analyzeRef(block, sema.src, array);
    const elem_index = try sema.resolveInst(bin_inst.rhs);
    const result_ptr = try sema.elemPtr(block, sema.src, array_ptr, elem_index, sema.src);
    return sema.analyzeLoad(block, sema.src, result_ptr, sema.src);
}

fn zirElemValNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const elem_index_src: LazySrcLoc = .{ .node_offset_array_access_index = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const array = try sema.resolveInst(extra.lhs);
    const array_ptr = if (array.ty.zigTypeTag() == .Pointer)
        array
    else
        try sema.analyzeRef(block, src, array);
    const elem_index = try sema.resolveInst(extra.rhs);
    const result_ptr = try sema.elemPtr(block, src, array_ptr, elem_index, elem_index_src);
    return sema.analyzeLoad(block, src, result_ptr, src);
}

fn zirElemPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const array_ptr = try sema.resolveInst(bin_inst.lhs);
    const elem_index = try sema.resolveInst(bin_inst.rhs);
    return sema.elemPtr(block, sema.src, array_ptr, elem_index, sema.src);
}

fn zirElemPtrNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const elem_index_src: LazySrcLoc = .{ .node_offset_array_access_index = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const array_ptr = try sema.resolveInst(extra.lhs);
    const elem_index = try sema.resolveInst(extra.rhs);
    return sema.elemPtr(block, src, array_ptr, elem_index, elem_index_src);
}

fn zirSliceStart(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.SliceStart, inst_data.payload_index).data;
    const array_ptr = try sema.resolveInst(extra.lhs);
    const start = try sema.resolveInst(extra.start);

    return sema.analyzeSlice(block, src, array_ptr, start, null, null, .unneeded);
}

fn zirSliceEnd(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.SliceEnd, inst_data.payload_index).data;
    const array_ptr = try sema.resolveInst(extra.lhs);
    const start = try sema.resolveInst(extra.start);
    const end = try sema.resolveInst(extra.end);

    return sema.analyzeSlice(block, src, array_ptr, start, end, null, .unneeded);
}

fn zirSliceSentinel(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const sentinel_src: LazySrcLoc = .{ .node_offset_slice_sentinel = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.SliceSentinel, inst_data.payload_index).data;
    const array_ptr = try sema.resolveInst(extra.lhs);
    const start = try sema.resolveInst(extra.start);
    const end = try sema.resolveInst(extra.end);
    const sentinel = try sema.resolveInst(extra.sentinel);

    return sema.analyzeSlice(block, src, array_ptr, start, end, sentinel, sentinel_src);
}

fn zirSwitchCapture(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    is_multi: bool,
    is_ref: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_datas = sema.code.instructions.items(.data);
    const capture_info = zir_datas[inst].switch_capture;
    const switch_info = zir_datas[capture_info.switch_inst].pl_node;
    const src = switch_info.src();

    return sema.mod.fail(&block.base, src, "TODO implement Sema for zirSwitchCapture", .{});
}

fn zirSwitchCaptureElse(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    is_ref: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const zir_datas = sema.code.instructions.items(.data);
    const capture_info = zir_datas[inst].switch_capture;
    const switch_info = zir_datas[capture_info.switch_inst].pl_node;
    const src = switch_info.src();

    return sema.mod.fail(&block.base, src, "TODO implement Sema for zirSwitchCaptureElse", .{});
}

fn zirSwitchBlock(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    is_ref: bool,
    special_prong: zir.SpecialProng,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.SwitchBlock, inst_data.payload_index);

    const operand_ptr = try sema.resolveInst(extra.data.operand);
    const operand = if (is_ref)
        try sema.analyzeLoad(block, src, operand_ptr, operand_src)
    else
        operand_ptr;

    return sema.analyzeSwitch(
        block,
        operand,
        extra.end,
        special_prong,
        extra.data.cases_len,
        0,
        inst,
        inst_data.src_node,
    );
}

fn zirSwitchBlockMulti(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    is_ref: bool,
    special_prong: zir.SpecialProng,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.SwitchBlockMulti, inst_data.payload_index);

    const operand_ptr = try sema.resolveInst(extra.data.operand);
    const operand = if (is_ref)
        try sema.analyzeLoad(block, src, operand_ptr, operand_src)
    else
        operand_ptr;

    return sema.analyzeSwitch(
        block,
        operand,
        extra.end,
        special_prong,
        extra.data.scalar_cases_len,
        extra.data.multi_cases_len,
        inst,
        inst_data.src_node,
    );
}

fn analyzeSwitch(
    sema: *Sema,
    block: *Scope.Block,
    operand: *Inst,
    extra_end: usize,
    special_prong: zir.SpecialProng,
    scalar_cases_len: usize,
    multi_cases_len: usize,
    switch_inst: zir.Inst.Index,
    src_node_offset: i32,
) InnerError!*Inst {
    const gpa = sema.gpa;
    const mod = sema.mod;

    const special: struct { body: []const zir.Inst.Index, end: usize } = switch (special_prong) {
        .none => .{ .body = &.{}, .end = extra_end },
        .under, .@"else" => blk: {
            const body_len = sema.code.extra[extra_end];
            const extra_body_start = extra_end + 1;
            break :blk .{
                .body = sema.code.extra[extra_body_start..][0..body_len],
                .end = extra_body_start + body_len,
            };
        },
    };

    const src: LazySrcLoc = .{ .node_offset = src_node_offset };
    const special_prong_src: LazySrcLoc = .{ .node_offset_switch_special_prong = src_node_offset };
    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = src_node_offset };

    // Validate usage of '_' prongs.
    if (special_prong == .under and !operand.ty.isNonexhaustiveEnum()) {
        const msg = msg: {
            const msg = try mod.errMsg(
                &block.base,
                src,
                "'_' prong only allowed when switching on non-exhaustive enums",
                .{},
            );
            errdefer msg.destroy(gpa);
            try mod.errNote(
                &block.base,
                special_prong_src,
                msg,
                "'_' prong here",
                .{},
            );
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(&block.base, msg);
    }

    // Validate for duplicate items, missing else prong, and invalid range.
    switch (operand.ty.zigTypeTag()) {
        .Enum => {
            var seen_fields = try gpa.alloc(?AstGen.SwitchProngSrc, operand.ty.enumFieldCount());
            defer gpa.free(seen_fields);

            mem.set(?AstGen.SwitchProngSrc, seen_fields, null);

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body = sema.code.extra[extra_index..][0..body_len];
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

                    try sema.validateSwitchNoRange(block, ranges_len, operand.ty, src_node_offset);
                }
            }
            const all_tags_handled = for (seen_fields) |seen_src| {
                if (seen_src == null) break false;
            } else true;

            switch (special_prong) {
                .none => {
                    if (!all_tags_handled) {
                        const msg = msg: {
                            const msg = try mod.errMsg(
                                &block.base,
                                src,
                                "switch must handle all possibilities",
                                .{},
                            );
                            errdefer msg.destroy(sema.gpa);
                            for (seen_fields) |seen_src, i| {
                                if (seen_src != null) continue;

                                const field_name = operand.ty.enumFieldName(i);

                                // TODO have this point to the tag decl instead of here
                                try mod.errNote(
                                    &block.base,
                                    src,
                                    msg,
                                    "unhandled enumeration value: '{s}'",
                                    .{field_name},
                                );
                            }
                            try mod.errNoteNonLazy(
                                operand.ty.declSrcLoc(),
                                msg,
                                "enum '{}' declared here",
                                .{operand.ty},
                            );
                            break :msg msg;
                        };
                        return mod.failWithOwnedErrorMsg(&block.base, msg);
                    }
                },
                .under => {
                    if (all_tags_handled) return mod.fail(
                        &block.base,
                        special_prong_src,
                        "unreachable '_' prong; all cases already handled",
                        .{},
                    );
                },
                .@"else" => {
                    if (all_tags_handled) return mod.fail(
                        &block.base,
                        special_prong_src,
                        "unreachable else prong; all cases already handled",
                        .{},
                    );
                },
            }
        },

        .ErrorSet => return mod.fail(&block.base, src, "TODO validate switch .ErrorSet", .{}),
        .Union => return mod.fail(&block.base, src, "TODO validate switch .Union", .{}),
        .Int, .ComptimeInt => {
            var range_set = RangeSet.init(gpa);
            defer range_set.deinit();

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body = sema.code.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    try sema.validateSwitchItem(
                        block,
                        &range_set,
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
                    extra_index += items_len;

                    for (items) |item_ref, item_i| {
                        try sema.validateSwitchItem(
                            block,
                            &range_set,
                            item_ref,
                            src_node_offset,
                            .{ .multi = .{ .prong = multi_i, .item = @intCast(u32, item_i) } },
                        );
                    }

                    var range_i: u32 = 0;
                    while (range_i < ranges_len) : (range_i += 1) {
                        const item_first = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                        extra_index += 1;
                        const item_last = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                        extra_index += 1;

                        try sema.validateSwitchRange(
                            block,
                            &range_set,
                            item_first,
                            item_last,
                            src_node_offset,
                            .{ .range = .{ .prong = multi_i, .item = range_i } },
                        );
                    }

                    extra_index += body_len;
                }
            }

            check_range: {
                if (operand.ty.zigTypeTag() == .Int) {
                    var arena = std.heap.ArenaAllocator.init(gpa);
                    defer arena.deinit();

                    const min_int = try operand.ty.minInt(&arena, mod.getTarget());
                    const max_int = try operand.ty.maxInt(&arena, mod.getTarget());
                    if (try range_set.spans(min_int, max_int)) {
                        if (special_prong == .@"else") {
                            return mod.fail(
                                &block.base,
                                special_prong_src,
                                "unreachable else prong; all cases already handled",
                                .{},
                            );
                        }
                        break :check_range;
                    }
                }
                if (special_prong != .@"else") {
                    return mod.fail(
                        &block.base,
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
                    const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body = sema.code.extra[extra_index..][0..body_len];
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

                    try sema.validateSwitchNoRange(block, ranges_len, operand.ty, src_node_offset);
                }
            }
            switch (special_prong) {
                .@"else" => {
                    if (true_count + false_count == 2) {
                        return mod.fail(
                            &block.base,
                            src,
                            "unreachable else prong; all cases already handled",
                            .{},
                        );
                    }
                },
                .under, .none => {
                    if (true_count + false_count < 2) {
                        return mod.fail(
                            &block.base,
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
                return mod.fail(
                    &block.base,
                    src,
                    "else prong required when switching on type '{}'",
                    .{operand.ty},
                );
            }

            var seen_values = ValueSrcMap.init(gpa);
            defer seen_values.deinit();

            var extra_index: usize = special.end;
            {
                var scalar_i: u32 = 0;
                while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                    const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const body_len = sema.code.extra[extra_index];
                    extra_index += 1;
                    const body = sema.code.extra[extra_index..][0..body_len];
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

                    try sema.validateSwitchNoRange(block, ranges_len, operand.ty, src_node_offset);
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
        => return mod.fail(&block.base, operand_src, "invalid switch operand type '{}'", .{
            operand.ty,
        }),
    }

    if (try sema.resolveDefinedValue(block, src, operand)) |operand_val| {
        var extra_index: usize = special.end;
        {
            var scalar_i: usize = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                extra_index += 1;
                const body_len = sema.code.extra[extra_index];
                extra_index += 1;
                const body = sema.code.extra[extra_index..][0..body_len];
                extra_index += body_len;

                // Validation above ensured these will succeed.
                const item = sema.resolveInst(item_ref) catch unreachable;
                const item_val = sema.resolveConstValue(block, .unneeded, item) catch unreachable;
                if (operand_val.eql(item_val)) {
                    return sema.resolveBody(block, body);
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
                    // Validation above ensured these will succeed.
                    const item = sema.resolveInst(item_ref) catch unreachable;
                    const item_val = sema.resolveConstValue(block, item.src, item) catch unreachable;
                    if (operand_val.eql(item_val)) {
                        return sema.resolveBody(block, body);
                    }
                }

                var range_i: usize = 0;
                while (range_i < ranges_len) : (range_i += 1) {
                    const item_first = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;
                    const item_last = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
                    extra_index += 1;

                    // Validation above ensured these will succeed.
                    const first_tv = sema.resolveInstConst(block, .unneeded, item_first) catch unreachable;
                    const last_tv = sema.resolveInstConst(block, .unneeded, item_last) catch unreachable;
                    if (Value.compare(operand_val, .gte, first_tv.val) and
                        Value.compare(operand_val, .lte, last_tv.val))
                    {
                        return sema.resolveBody(block, body);
                    }
                }

                extra_index += body_len;
            }
        }
        return sema.resolveBody(block, special.body);
    }

    if (scalar_cases_len + multi_cases_len == 0) {
        return sema.resolveBody(block, special.body);
    }

    try sema.requireRuntimeBlock(block, src);

    const block_inst = try sema.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = undefined, // Set after analysis.
            .src = src,
        },
        .body = undefined,
    };

    var child_block: Scope.Block = .{
        .parent = block,
        .sema = sema,
        .src_decl = block.src_decl,
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?Scope.Block.Label, Scope.Block.Label{
            .zir_block = switch_inst,
            .merges = .{
                .results = .{},
                .br_list = .{},
                .block_inst = block_inst,
            },
        }),
        .inlining = block.inlining,
        .is_comptime = block.is_comptime,
    };
    const merges = &child_block.label.?.merges;
    defer child_block.instructions.deinit(gpa);
    defer merges.results.deinit(gpa);
    defer merges.br_list.deinit(gpa);

    // TODO when reworking TZIR memory layout make multi cases get generated as cases,
    // not as part of the "else" block.
    const cases = try sema.arena.alloc(Inst.SwitchBr.Case, scalar_cases_len);

    var case_block = child_block.makeSubBlock();
    defer case_block.instructions.deinit(gpa);

    var extra_index: usize = special.end;

    var scalar_i: usize = 0;
    while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
        const item_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
        extra_index += 1;
        const body_len = sema.code.extra[extra_index];
        extra_index += 1;
        const body = sema.code.extra[extra_index..][0..body_len];
        extra_index += body_len;

        case_block.instructions.shrinkRetainingCapacity(0);
        // We validate these above; these two calls are guaranteed to succeed.
        const item = sema.resolveInst(item_ref) catch unreachable;
        const item_val = sema.resolveConstValue(&case_block, .unneeded, item) catch unreachable;

        _ = try sema.analyzeBody(&case_block, body);

        cases[scalar_i] = .{
            .item = item_val,
            .body = .{ .instructions = try sema.arena.dupe(*Inst, case_block.instructions.items) },
        };
    }

    var first_else_body: Body = undefined;
    var prev_condbr: ?*Inst.CondBr = null;

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

        var any_ok: ?*Inst = null;
        const bool_ty = comptime Type.initTag(.bool);

        for (items) |item_ref| {
            const item = try sema.resolveInst(item_ref);
            _ = try sema.resolveConstValue(&child_block, item.src, item);

            const cmp_ok = try case_block.addBinOp(item.src, bool_ty, .cmp_eq, operand, item);
            if (any_ok) |some| {
                any_ok = try case_block.addBinOp(item.src, bool_ty, .bool_or, some, cmp_ok);
            } else {
                any_ok = cmp_ok;
            }
        }

        var range_i: usize = 0;
        while (range_i < ranges_len) : (range_i += 1) {
            const first_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
            extra_index += 1;
            const last_ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_index]);
            extra_index += 1;

            const item_first = try sema.resolveInst(first_ref);
            const item_last = try sema.resolveInst(last_ref);

            _ = try sema.resolveConstValue(&child_block, item_first.src, item_first);
            _ = try sema.resolveConstValue(&child_block, item_last.src, item_last);

            const range_src = item_first.src;

            // operand >= first and operand <= last
            const range_first_ok = try case_block.addBinOp(
                item_first.src,
                bool_ty,
                .cmp_gte,
                operand,
                item_first,
            );
            const range_last_ok = try case_block.addBinOp(
                item_last.src,
                bool_ty,
                .cmp_lte,
                operand,
                item_last,
            );
            const range_ok = try case_block.addBinOp(
                range_src,
                bool_ty,
                .bool_and,
                range_first_ok,
                range_last_ok,
            );
            if (any_ok) |some| {
                any_ok = try case_block.addBinOp(range_src, bool_ty, .bool_or, some, range_ok);
            } else {
                any_ok = range_ok;
            }
        }

        const new_condbr = try sema.arena.create(Inst.CondBr);
        new_condbr.* = .{
            .base = .{
                .tag = .condbr,
                .ty = Type.initTag(.noreturn),
                .src = src,
            },
            .condition = any_ok.?,
            .then_body = undefined,
            .else_body = undefined,
        };
        try case_block.instructions.append(gpa, &new_condbr.base);

        const cond_body: Body = .{
            .instructions = try sema.arena.dupe(*Inst, case_block.instructions.items),
        };

        case_block.instructions.shrinkRetainingCapacity(0);
        const body = sema.code.extra[extra_index..][0..body_len];
        extra_index += body_len;
        _ = try sema.analyzeBody(&case_block, body);
        new_condbr.then_body = .{
            .instructions = try sema.arena.dupe(*Inst, case_block.instructions.items),
        };
        if (prev_condbr) |condbr| {
            condbr.else_body = cond_body;
        } else {
            first_else_body = cond_body;
        }
        prev_condbr = new_condbr;
    }

    const final_else_body: Body = blk: {
        if (special.body.len != 0) {
            case_block.instructions.shrinkRetainingCapacity(0);
            _ = try sema.analyzeBody(&case_block, special.body);
            const else_body: Body = .{
                .instructions = try sema.arena.dupe(*Inst, case_block.instructions.items),
            };
            if (prev_condbr) |condbr| {
                condbr.else_body = else_body;
                break :blk first_else_body;
            } else {
                break :blk else_body;
            }
        } else {
            break :blk .{ .instructions = &.{} };
        }
    };

    _ = try child_block.addSwitchBr(src, operand, cases, final_else_body);
    return sema.analyzeBlockBody(block, src, &child_block, merges);
}

fn resolveSwitchItemVal(
    sema: *Sema,
    block: *Scope.Block,
    item_ref: zir.Inst.Ref,
    switch_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
    range_expand: AstGen.SwitchProngSrc.RangeExpand,
) InnerError!TypedValue {
    const item = try sema.resolveInst(item_ref);
    // We have to avoid the other helper functions here because we cannot construct a LazySrcLoc
    // because we only have the switch AST node. Only if we know for sure we need to report
    // a compile error do we resolve the full source locations.
    if (item.value()) |val| {
        if (val.isUndef()) {
            const src = switch_prong_src.resolve(block.src_decl, switch_node_offset, range_expand);
            return sema.failWithUseOfUndef(block, src);
        }
        return TypedValue{ .ty = item.ty, .val = val };
    }
    const src = switch_prong_src.resolve(block.src_decl, switch_node_offset, range_expand);
    return sema.failWithNeededComptime(block, src);
}

fn validateSwitchRange(
    sema: *Sema,
    block: *Scope.Block,
    range_set: *RangeSet,
    first_ref: zir.Inst.Ref,
    last_ref: zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
) InnerError!void {
    const first_val = (try sema.resolveSwitchItemVal(block, first_ref, src_node_offset, switch_prong_src, .first)).val;
    const last_val = (try sema.resolveSwitchItemVal(block, last_ref, src_node_offset, switch_prong_src, .last)).val;
    const maybe_prev_src = try range_set.add(first_val, last_val, switch_prong_src);
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchItem(
    sema: *Sema,
    block: *Scope.Block,
    range_set: *RangeSet,
    item_ref: zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
) InnerError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    const maybe_prev_src = try range_set.add(item_val, item_val, switch_prong_src);
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchItemEnum(
    sema: *Sema,
    block: *Scope.Block,
    seen_fields: []?AstGen.SwitchProngSrc,
    item_ref: zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
) InnerError!void {
    const mod = sema.mod;
    const item_tv = try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none);
    const field_index = item_tv.ty.enumTagFieldIndex(item_tv.val) orelse {
        const msg = msg: {
            const src = switch_prong_src.resolve(block.src_decl, src_node_offset, .none);
            const msg = try mod.errMsg(
                &block.base,
                src,
                "enum '{}' has no tag with value '{}'",
                .{ item_tv.ty, item_tv.val },
            );
            errdefer msg.destroy(sema.gpa);
            try mod.errNoteNonLazy(
                item_tv.ty.declSrcLoc(),
                msg,
                "enum declared here",
                .{},
            );
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(&block.base, msg);
    };
    const maybe_prev_src = seen_fields[field_index];
    seen_fields[field_index] = switch_prong_src;
    return sema.validateSwitchDupe(block, maybe_prev_src, switch_prong_src, src_node_offset);
}

fn validateSwitchDupe(
    sema: *Sema,
    block: *Scope.Block,
    maybe_prev_src: ?AstGen.SwitchProngSrc,
    switch_prong_src: AstGen.SwitchProngSrc,
    src_node_offset: i32,
) InnerError!void {
    const prev_prong_src = maybe_prev_src orelse return;
    const mod = sema.mod;
    const src = switch_prong_src.resolve(block.src_decl, src_node_offset, .none);
    const prev_src = prev_prong_src.resolve(block.src_decl, src_node_offset, .none);
    const msg = msg: {
        const msg = try mod.errMsg(
            &block.base,
            src,
            "duplicate switch value",
            .{},
        );
        errdefer msg.destroy(sema.gpa);
        try mod.errNote(
            &block.base,
            prev_src,
            msg,
            "previous value here",
            .{},
        );
        break :msg msg;
    };
    return mod.failWithOwnedErrorMsg(&block.base, msg);
}

fn validateSwitchItemBool(
    sema: *Sema,
    block: *Scope.Block,
    true_count: *u8,
    false_count: *u8,
    item_ref: zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
) InnerError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    if (item_val.toBool()) {
        true_count.* += 1;
    } else {
        false_count.* += 1;
    }
    if (true_count.* + false_count.* > 2) {
        const src = switch_prong_src.resolve(block.src_decl, src_node_offset, .none);
        return sema.mod.fail(&block.base, src, "duplicate switch value", .{});
    }
}

const ValueSrcMap = std.HashMap(Value, AstGen.SwitchProngSrc, Value.hash, Value.eql, std.hash_map.DefaultMaxLoadPercentage);

fn validateSwitchItemSparse(
    sema: *Sema,
    block: *Scope.Block,
    seen_values: *ValueSrcMap,
    item_ref: zir.Inst.Ref,
    src_node_offset: i32,
    switch_prong_src: AstGen.SwitchProngSrc,
) InnerError!void {
    const item_val = (try sema.resolveSwitchItemVal(block, item_ref, src_node_offset, switch_prong_src, .none)).val;
    const entry = (try seen_values.fetchPut(item_val, switch_prong_src)) orelse return;
    return sema.validateSwitchDupe(block, entry.value, switch_prong_src, src_node_offset);
}

fn validateSwitchNoRange(
    sema: *Sema,
    block: *Scope.Block,
    ranges_len: u32,
    operand_ty: Type,
    src_node_offset: i32,
) InnerError!void {
    if (ranges_len == 0)
        return;

    const operand_src: LazySrcLoc = .{ .node_offset_switch_operand = src_node_offset };
    const range_src: LazySrcLoc = .{ .node_offset_switch_range = src_node_offset };

    const msg = msg: {
        const msg = try sema.mod.errMsg(
            &block.base,
            operand_src,
            "ranges not allowed when switching on type '{}'",
            .{operand_ty},
        );
        errdefer msg.destroy(sema.gpa);
        try sema.mod.errNote(
            &block.base,
            range_src,
            msg,
            "range here",
            .{},
        );
        break :msg msg;
    };
    return sema.mod.failWithOwnedErrorMsg(&block.base, msg);
}

fn zirHasDecl(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_builtin_call_arg1 = inst_data.src_node };
    const container_type = try sema.resolveType(block, lhs_src, extra.lhs);
    const decl_name = try sema.resolveConstString(block, rhs_src, extra.rhs);
    const mod = sema.mod;
    const arena = sema.arena;

    const container_scope = container_type.getContainerScope() orelse return mod.fail(
        &block.base,
        lhs_src,
        "expected struct, enum, union, or opaque, found '{}'",
        .{container_type},
    );
    if (mod.lookupDeclName(&container_scope.base, decl_name)) |decl| {
        // TODO if !decl.is_pub and inDifferentFiles() return false
        return mod.constBool(arena, src, true);
    } else {
        return mod.constBool(arena, src, false);
    }
}

fn zirImport(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_src: LazySrcLoc = .{ .node_offset_builtin_call_arg0 = inst_data.src_node };
    const operand = try sema.resolveConstString(block, operand_src, inst_data.operand);

    const file_scope = sema.analyzeImport(block, src, operand) catch |err| switch (err) {
        error.ImportOutsidePkgPath => {
            return sema.mod.fail(&block.base, src, "import of file outside package path: '{s}'", .{operand});
        },
        error.FileNotFound => {
            return sema.mod.fail(&block.base, src, "unable to find '{s}'", .{operand});
        },
        else => {
            // TODO: make sure this gets retried and not cached
            return sema.mod.fail(&block.base, src, "unable to open '{s}': {s}", .{ operand, @errorName(err) });
        },
    };
    return sema.mod.constType(sema.arena, src, file_scope.root_container.ty);
}

fn zirShl(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirShl", .{});
}

fn zirShr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirShr", .{});
}

fn zirBitwise(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    ir_tag: ir.Inst.Tag,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = try sema.resolveInst(extra.lhs);
    const rhs = try sema.resolveInst(extra.rhs);

    const instructions = &[_]*Inst{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions);
    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    if (lhs.ty.zigTypeTag() == .Vector and rhs.ty.zigTypeTag() == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return sema.mod.fail(&block.base, src, "vector length mismatch: {d} and {d}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return sema.mod.fail(&block.base, src, "TODO implement support for vectors in zirBitwise", .{});
    } else if (lhs.ty.zigTypeTag() == .Vector or rhs.ty.zigTypeTag() == .Vector) {
        return sema.mod.fail(&block.base, src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;

    if (!is_int) {
        return sema.mod.fail(&block.base, src, "invalid operands to binary bitwise expression: '{s}' and '{s}'", .{ @tagName(lhs.ty.zigTypeTag()), @tagName(rhs.ty.zigTypeTag()) });
    }

    if (casted_lhs.value()) |lhs_val| {
        if (casted_rhs.value()) |rhs_val| {
            if (lhs_val.isUndef() or rhs_val.isUndef()) {
                return sema.mod.constInst(sema.arena, src, .{
                    .ty = resolved_type,
                    .val = Value.initTag(.undef),
                });
            }
            return sema.mod.fail(&block.base, src, "TODO implement comptime bitwise operations", .{});
        }
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addBinOp(src, scalar_type, ir_tag, casted_lhs, casted_rhs);
}

fn zirBitNot(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirBitNot", .{});
}

fn zirArrayCat(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirArrayCat", .{});
}

fn zirArrayMul(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return sema.mod.fail(&block.base, sema.src, "TODO implement zirArrayMul", .{});
}

fn zirNegate(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    tag_override: zir.Inst.Tag,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs = try sema.resolveInst(.zero);
    const rhs = try sema.resolveInst(inst_data.operand);

    return sema.analyzeArithmetic(block, tag_override, lhs, rhs, src, lhs_src, rhs_src);
}

fn zirArithmetic(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const tag_override = block.sema.code.instructions.items(.tag)[inst];
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src: LazySrcLoc = .{ .node_offset_bin_op = inst_data.src_node };
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const lhs = try sema.resolveInst(extra.lhs);
    const rhs = try sema.resolveInst(extra.rhs);

    return sema.analyzeArithmetic(block, tag_override, lhs, rhs, src, lhs_src, rhs_src);
}

fn analyzeArithmetic(
    sema: *Sema,
    block: *Scope.Block,
    zir_tag: zir.Inst.Tag,
    lhs: *Inst,
    rhs: *Inst,
    src: LazySrcLoc,
    lhs_src: LazySrcLoc,
    rhs_src: LazySrcLoc,
) InnerError!*Inst {
    const instructions = &[_]*Inst{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions);
    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    if (lhs.ty.zigTypeTag() == .Vector and rhs.ty.zigTypeTag() == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return sema.mod.fail(&block.base, src, "vector length mismatch: {d} and {d}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return sema.mod.fail(&block.base, src, "TODO implement support for vectors in zirBinOp", .{});
    } else if (lhs.ty.zigTypeTag() == .Vector or rhs.ty.zigTypeTag() == .Vector) {
        return sema.mod.fail(&block.base, src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;
    const is_float = scalar_tag == .Float or scalar_tag == .ComptimeFloat;

    if (!is_int and !(is_float and floatOpAllowed(zir_tag))) {
        return sema.mod.fail(&block.base, src, "invalid operands to binary expression: '{s}' and '{s}'", .{ @tagName(lhs.ty.zigTypeTag()), @tagName(rhs.ty.zigTypeTag()) });
    }

    if (casted_lhs.value()) |lhs_val| {
        if (casted_rhs.value()) |rhs_val| {
            if (lhs_val.isUndef() or rhs_val.isUndef()) {
                return sema.mod.constInst(sema.arena, src, .{
                    .ty = resolved_type,
                    .val = Value.initTag(.undef),
                });
            }
            // incase rhs is 0, simply return lhs without doing any calculations
            // TODO Once division is implemented we should throw an error when dividing by 0.
            if (rhs_val.compareWithZero(.eq)) {
                return sema.mod.constInst(sema.arena, src, .{
                    .ty = scalar_type,
                    .val = lhs_val,
                });
            }

            const value = switch (zir_tag) {
                .add => blk: {
                    const val = if (is_int)
                        try Module.intAdd(sema.arena, lhs_val, rhs_val)
                    else
                        try Module.floatAdd(sema.arena, scalar_type, src, lhs_val, rhs_val);
                    break :blk val;
                },
                .sub => blk: {
                    const val = if (is_int)
                        try Module.intSub(sema.arena, lhs_val, rhs_val)
                    else
                        try Module.floatSub(sema.arena, scalar_type, src, lhs_val, rhs_val);
                    break :blk val;
                },
                else => return sema.mod.fail(&block.base, src, "TODO Implement arithmetic operand '{s}'", .{@tagName(zir_tag)}),
            };

            log.debug("{s}({}, {}) result: {}", .{ @tagName(zir_tag), lhs_val, rhs_val, value });

            return sema.mod.constInst(sema.arena, src, .{
                .ty = scalar_type,
                .val = value,
            });
        }
    }

    try sema.requireRuntimeBlock(block, src);
    const ir_tag: Inst.Tag = switch (zir_tag) {
        .add => .add,
        .addwrap => .addwrap,
        .sub => .sub,
        .subwrap => .subwrap,
        .mul => .mul,
        .mulwrap => .mulwrap,
        .div => .div,
        else => return sema.mod.fail(&block.base, src, "TODO implement arithmetic for operand '{s}''", .{@tagName(zir_tag)}),
    };

    return block.addBinOp(src, scalar_type, ir_tag, casted_lhs, casted_rhs);
}

fn zirLoad(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr_src: LazySrcLoc = .{ .node_offset_deref_ptr = inst_data.src_node };
    const ptr = try sema.resolveInst(inst_data.operand);
    return sema.analyzeLoad(block, src, ptr, ptr_src);
}

fn zirAsm(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    is_volatile: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const asm_source_src: LazySrcLoc = .{ .node_offset_asm_source = inst_data.src_node };
    const ret_ty_src: LazySrcLoc = .{ .node_offset_asm_ret_ty = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.Asm, inst_data.payload_index);
    const return_type = try sema.resolveType(block, ret_ty_src, extra.data.return_type);
    const asm_source = try sema.resolveConstString(block, asm_source_src, extra.data.asm_source);

    var extra_i = extra.end;
    const Output = struct { name: []const u8, inst: *Inst };
    const output: ?Output = if (extra.data.output != .none) blk: {
        const name = sema.code.nullTerminatedString(sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk Output{
            .name = name,
            .inst = try sema.resolveInst(extra.data.output),
        };
    } else null;

    const args = try sema.arena.alloc(*Inst, extra.data.args_len);
    const inputs = try sema.arena.alloc([]const u8, extra.data.args_len);
    const clobbers = try sema.arena.alloc([]const u8, extra.data.clobbers_len);

    for (args) |*arg| {
        arg.* = try sema.resolveInst(@intToEnum(zir.Inst.Ref, sema.code.extra[extra_i]));
        extra_i += 1;
    }
    for (inputs) |*name| {
        name.* = sema.code.nullTerminatedString(sema.code.extra[extra_i]);
        extra_i += 1;
    }
    for (clobbers) |*name| {
        name.* = sema.code.nullTerminatedString(sema.code.extra[extra_i]);
        extra_i += 1;
    }

    try sema.requireRuntimeBlock(block, src);
    const asm_tzir = try sema.arena.create(Inst.Assembly);
    asm_tzir.* = .{
        .base = .{
            .tag = .assembly,
            .ty = return_type,
            .src = src,
        },
        .asm_source = asm_source,
        .is_volatile = is_volatile,
        .output = if (output) |o| o.inst else null,
        .output_name = if (output) |o| o.name else null,
        .inputs = inputs,
        .clobbers = clobbers,
        .args = args,
    };
    try block.instructions.append(sema.gpa, &asm_tzir.base);
    return &asm_tzir.base;
}

fn zirCmp(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    op: std.math.CompareOperator,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = sema.mod;

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const extra = sema.code.extraData(zir.Inst.Bin, inst_data.payload_index).data;
    const src: LazySrcLoc = inst_data.src();
    const lhs_src: LazySrcLoc = .{ .node_offset_bin_lhs = inst_data.src_node };
    const rhs_src: LazySrcLoc = .{ .node_offset_bin_rhs = inst_data.src_node };
    const lhs = try sema.resolveInst(extra.lhs);
    const rhs = try sema.resolveInst(extra.rhs);

    const is_equality_cmp = switch (op) {
        .eq, .neq => true,
        else => false,
    };
    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();
    if (is_equality_cmp and lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
        // null == null, null != null
        return mod.constBool(sema.arena, src, op == .eq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
        rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
    {
        // comparing null with optionals
        const opt_operand = if (lhs_ty_tag == .Optional) lhs else rhs;
        return sema.analyzeIsNull(block, src, opt_operand, op == .neq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs.ty.isCPtr()) or (rhs_ty_tag == .Null and lhs.ty.isCPtr())))
    {
        return mod.fail(&block.base, src, "TODO implement C pointer cmp", .{});
    } else if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
        const non_null_type = if (lhs_ty_tag == .Null) rhs.ty else lhs.ty;
        return mod.fail(&block.base, src, "comparison of '{}' with null", .{non_null_type});
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) or
        (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union)))
    {
        return mod.fail(&block.base, src, "TODO implement equality comparison between a union's tag value and an enum literal", .{});
    } else if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
        if (!is_equality_cmp) {
            return mod.fail(&block.base, src, "{s} operator not allowed for errors", .{@tagName(op)});
        }
        if (rhs.value()) |rval| {
            if (lhs.value()) |lval| {
                // TODO optimisation oppurtunity: evaluate if std.mem.eql is faster with the names, or calling to Module.getErrorValue to get the values and then compare them is faster
                return mod.constBool(sema.arena, src, std.mem.eql(u8, lval.castTag(.@"error").?.data.name, rval.castTag(.@"error").?.data.name) == (op == .eq));
            }
        }
        try sema.requireRuntimeBlock(block, src);
        return block.addBinOp(src, Type.initTag(.bool), if (op == .eq) .cmp_eq else .cmp_neq, lhs, rhs);
    } else if (lhs.ty.isNumeric() and rhs.ty.isNumeric()) {
        // This operation allows any combination of integer and float types, regardless of the
        // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
        // numeric types.
        return sema.cmpNumeric(block, src, lhs, rhs, op);
    } else if (lhs_ty_tag == .Type and rhs_ty_tag == .Type) {
        if (!is_equality_cmp) {
            return mod.fail(&block.base, src, "{s} operator not allowed for types", .{@tagName(op)});
        }
        return mod.constBool(sema.arena, src, lhs.value().?.eql(rhs.value().?) == (op == .eq));
    }

    const instructions = &[_]*Inst{ lhs, rhs };
    const resolved_type = try sema.resolvePeerTypes(block, src, instructions);
    if (!resolved_type.isSelfComparable(is_equality_cmp)) {
        return mod.fail(&block.base, src, "operator not allowed for type '{}'", .{resolved_type});
    }

    const casted_lhs = try sema.coerce(block, resolved_type, lhs, lhs_src);
    const casted_rhs = try sema.coerce(block, resolved_type, rhs, rhs_src);
    try sema.requireRuntimeBlock(block, src); // TODO try to do it at comptime
    const bool_type = Type.initTag(.bool); // TODO handle vectors
    const tag: Inst.Tag = switch (op) {
        .lt => .cmp_lt,
        .lte => .cmp_lte,
        .eq => .cmp_eq,
        .gte => .cmp_gte,
        .gt => .cmp_gt,
        .neq => .cmp_neq,
    };
    return block.addBinOp(src, bool_type, tag, casted_lhs, casted_rhs);
}

fn zirTypeInfo(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    return sema.mod.fail(&block.base, src, "TODO: implement Sema.zirTypeInfo", .{});
}

fn zirTypeof(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    return sema.mod.constType(sema.arena, src, operand.ty);
}

fn zirTypeofElem(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand_ptr = try sema.resolveInst(inst_data.operand);
    const elem_ty = operand_ptr.ty.elemType();
    return sema.mod.constType(sema.arena, src, elem_ty);
}

fn zirTypeofPeer(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const extra = sema.code.extraData(zir.Inst.MultiOp, inst_data.payload_index);
    const args = sema.code.refSlice(extra.end, extra.data.operands_len);

    const inst_list = try sema.gpa.alloc(*ir.Inst, extra.data.operands_len);
    defer sema.gpa.free(inst_list);

    for (args) |arg_ref, i| {
        inst_list[i] = try sema.resolveInst(arg_ref);
    }

    const result_type = try sema.resolvePeerTypes(block, src, inst_list);
    return sema.mod.constType(sema.arena, src, result_type);
}

fn zirBoolNot(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const uncasted_operand = try sema.resolveInst(inst_data.operand);

    const bool_type = Type.initTag(.bool);
    const operand = try sema.coerce(block, bool_type, uncasted_operand, uncasted_operand.src);
    if (try sema.resolveDefinedValue(block, src, operand)) |val| {
        return sema.mod.constBool(sema.arena, src, !val.toBool());
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, bool_type, .not, operand);
}

fn zirBoolOp(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    comptime is_bool_or: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    const bool_type = Type.initTag(.bool);
    const bin_inst = sema.code.instructions.items(.data)[inst].bin;
    const uncasted_lhs = try sema.resolveInst(bin_inst.lhs);
    const lhs = try sema.coerce(block, bool_type, uncasted_lhs, uncasted_lhs.src);
    const uncasted_rhs = try sema.resolveInst(bin_inst.rhs);
    const rhs = try sema.coerce(block, bool_type, uncasted_rhs, uncasted_rhs.src);

    if (lhs.value()) |lhs_val| {
        if (rhs.value()) |rhs_val| {
            if (is_bool_or) {
                return sema.mod.constBool(sema.arena, src, lhs_val.toBool() or rhs_val.toBool());
            } else {
                return sema.mod.constBool(sema.arena, src, lhs_val.toBool() and rhs_val.toBool());
            }
        }
    }
    try sema.requireRuntimeBlock(block, src);
    const tag: ir.Inst.Tag = if (is_bool_or) .bool_or else .bool_and;
    return block.addBinOp(src, bool_type, tag, lhs, rhs);
}

fn zirBoolBr(
    sema: *Sema,
    parent_block: *Scope.Block,
    inst: zir.Inst.Index,
    is_bool_or: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const datas = sema.code.instructions.items(.data);
    const inst_data = datas[inst].bool_br;
    const src: LazySrcLoc = .unneeded;
    const lhs = try sema.resolveInst(inst_data.lhs);
    const extra = sema.code.extraData(zir.Inst.Block, inst_data.payload_index);
    const body = sema.code.extra[extra.end..][0..extra.data.body_len];

    if (try sema.resolveDefinedValue(parent_block, src, lhs)) |lhs_val| {
        if (lhs_val.toBool() == is_bool_or) {
            return sema.mod.constBool(sema.arena, src, is_bool_or);
        }
        // comptime-known left-hand side. No need for a block here; the result
        // is simply the rhs expression. Here we rely on there only being 1
        // break instruction (`break_inline`).
        return sema.resolveBody(parent_block, body);
    }

    const block_inst = try sema.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = Type.initTag(.bool),
            .src = src,
        },
        .body = undefined,
    };

    var child_block = parent_block.makeSubBlock();
    defer child_block.instructions.deinit(sema.gpa);

    var then_block = child_block.makeSubBlock();
    defer then_block.instructions.deinit(sema.gpa);

    var else_block = child_block.makeSubBlock();
    defer else_block.instructions.deinit(sema.gpa);

    const lhs_block = if (is_bool_or) &then_block else &else_block;
    const rhs_block = if (is_bool_or) &else_block else &then_block;

    const lhs_result = try sema.mod.constInst(sema.arena, src, .{
        .ty = Type.initTag(.bool),
        .val = if (is_bool_or) Value.initTag(.bool_true) else Value.initTag(.bool_false),
    });
    _ = try lhs_block.addBr(src, block_inst, lhs_result);

    const rhs_result = try sema.resolveBody(rhs_block, body);
    _ = try rhs_block.addBr(src, block_inst, rhs_result);

    const tzir_then_body: ir.Body = .{ .instructions = try sema.arena.dupe(*Inst, then_block.instructions.items) };
    const tzir_else_body: ir.Body = .{ .instructions = try sema.arena.dupe(*Inst, else_block.instructions.items) };
    _ = try child_block.addCondBr(src, lhs, tzir_then_body, tzir_else_body);

    block_inst.body = .{
        .instructions = try sema.arena.dupe(*Inst, child_block.instructions.items),
    };
    try parent_block.instructions.append(sema.gpa, &block_inst.base);
    return &block_inst.base;
}

fn zirIsNull(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    invert_logic: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const operand = try sema.resolveInst(inst_data.operand);
    return sema.analyzeIsNull(block, src, operand, invert_logic);
}

fn zirIsNullPtr(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    invert_logic: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr = try sema.resolveInst(inst_data.operand);
    const loaded = try sema.analyzeLoad(block, src, ptr, src);
    return sema.analyzeIsNull(block, src, loaded, invert_logic);
}

fn zirIsErr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = try sema.resolveInst(inst_data.operand);
    return sema.analyzeIsErr(block, inst_data.src(), operand);
}

fn zirIsErrPtr(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const ptr = try sema.resolveInst(inst_data.operand);
    const loaded = try sema.analyzeLoad(block, src, ptr, src);
    return sema.analyzeIsErr(block, src, loaded);
}

fn zirCondbr(
    sema: *Sema,
    parent_block: *Scope.Block,
    inst: zir.Inst.Index,
) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    const cond_src: LazySrcLoc = .{ .node_offset_if_cond = inst_data.src_node };
    const extra = sema.code.extraData(zir.Inst.CondBr, inst_data.payload_index);

    const then_body = sema.code.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = sema.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];

    const uncasted_cond = try sema.resolveInst(extra.data.condition);
    const cond = try sema.coerce(parent_block, Type.initTag(.bool), uncasted_cond, cond_src);

    if (try sema.resolveDefinedValue(parent_block, src, cond)) |cond_val| {
        const body = if (cond_val.toBool()) then_body else else_body;
        _ = try sema.analyzeBody(parent_block, body);
        return always_noreturn;
    }

    var sub_block = parent_block.makeSubBlock();
    defer sub_block.instructions.deinit(sema.gpa);

    _ = try sema.analyzeBody(&sub_block, then_body);
    const tzir_then_body: ir.Body = .{
        .instructions = try sema.arena.dupe(*Inst, sub_block.instructions.items),
    };

    sub_block.instructions.shrinkRetainingCapacity(0);

    _ = try sema.analyzeBody(&sub_block, else_body);
    const tzir_else_body: ir.Body = .{
        .instructions = try sema.arena.dupe(*Inst, sub_block.instructions.items),
    };

    _ = try parent_block.addCondBr(src, cond, tzir_then_body, tzir_else_body);
    return always_noreturn;
}

fn zirUnreachable(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].@"unreachable";
    const src = inst_data.src();
    const safety_check = inst_data.safety;
    try sema.requireRuntimeBlock(block, src);
    // TODO Add compile error for @optimizeFor occurring too late in a scope.
    if (safety_check and block.wantSafety()) {
        return sema.safetyPanic(block, src, .unreach);
    } else {
        _ = try block.addNoOp(src, Type.initTag(.noreturn), .unreach);
        return always_noreturn;
    }
}

fn zirRetTok(
    sema: *Sema,
    block: *Scope.Block,
    inst: zir.Inst.Index,
    need_coercion: bool,
) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_tok;
    const operand = try sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.analyzeRet(block, operand, src, need_coercion);
}

fn zirRetNode(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!zir.Inst.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const operand = try sema.resolveInst(inst_data.operand);
    const src = inst_data.src();

    return sema.analyzeRet(block, operand, src, false);
}

fn analyzeRet(
    sema: *Sema,
    block: *Scope.Block,
    operand: *Inst,
    src: LazySrcLoc,
    need_coercion: bool,
) InnerError!zir.Inst.Index {
    if (block.inlining) |inlining| {
        // We are inlining a function call; rewrite the `ret` as a `break`.
        try inlining.merges.results.append(sema.gpa, operand);
        _ = try block.addBr(src, inlining.merges.block_inst, operand);
        return always_noreturn;
    }

    if (need_coercion) {
        if (sema.func) |func| {
            const fn_ty = func.owner_decl.typed_value.most_recent.typed_value.ty;
            const fn_ret_ty = fn_ty.fnReturnType();
            const casted_operand = try sema.coerce(block, fn_ret_ty, operand, src);
            if (fn_ret_ty.zigTypeTag() == .Void)
                _ = try block.addNoOp(src, Type.initTag(.noreturn), .retvoid)
            else
                _ = try block.addUnOp(src, Type.initTag(.noreturn), .ret, casted_operand);
            return always_noreturn;
        }
    }
    _ = try block.addUnOp(src, Type.initTag(.noreturn), .ret, operand);
    return always_noreturn;
}

fn floatOpAllowed(tag: zir.Inst.Tag) bool {
    // extend this swich as additional operators are implemented
    return switch (tag) {
        .add, .sub => true,
        else => false,
    };
}

fn zirPtrTypeSimple(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].ptr_type_simple;
    const elem_type = try sema.resolveType(block, .unneeded, inst_data.elem_type);
    const ty = try sema.mod.ptrType(
        sema.arena,
        elem_type,
        null,
        0,
        0,
        0,
        inst_data.is_mutable,
        inst_data.is_allowzero,
        inst_data.is_volatile,
        inst_data.size,
    );
    return sema.mod.constType(sema.arena, .unneeded, ty);
}

fn zirPtrType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const src: LazySrcLoc = .unneeded;
    const inst_data = sema.code.instructions.items(.data)[inst].ptr_type;
    const extra = sema.code.extraData(zir.Inst.PtrType, inst_data.payload_index);

    var extra_i = extra.end;

    const sentinel = if (inst_data.flags.has_sentinel) blk: {
        const ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk (try sema.resolveInstConst(block, .unneeded, ref)).val;
    } else null;

    const abi_align = if (inst_data.flags.has_align) blk: {
        const ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u32);
    } else 0;

    const bit_start = if (inst_data.flags.has_bit_range) blk: {
        const ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u16);
    } else 0;

    const bit_end = if (inst_data.flags.has_bit_range) blk: {
        const ref = @intToEnum(zir.Inst.Ref, sema.code.extra[extra_i]);
        extra_i += 1;
        break :blk try sema.resolveAlreadyCoercedInt(block, .unneeded, ref, u16);
    } else 0;

    if (bit_end != 0 and bit_start >= bit_end * 8)
        return sema.mod.fail(&block.base, src, "bit offset starts after end of host integer", .{});

    const elem_type = try sema.resolveType(block, .unneeded, extra.data.elem_type);

    const ty = try sema.mod.ptrType(
        sema.arena,
        elem_type,
        sentinel,
        abi_align,
        bit_start,
        bit_end,
        inst_data.flags.is_mutable,
        inst_data.flags.is_allowzero,
        inst_data.flags.is_volatile,
        inst_data.size,
    );
    return sema.mod.constType(sema.arena, src, ty);
}

fn zirStructInitEmpty(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const inst_data = sema.code.instructions.items(.data)[inst].un_node;
    const src = inst_data.src();
    const struct_type = try sema.resolveType(block, src, inst_data.operand);

    return sema.mod.constInst(sema.arena, src, .{
        .ty = struct_type,
        .val = Value.initTag(.empty_struct_value),
    });
}

fn zirStructInit(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.mod.fail(&block.base, src, "TODO: Sema.zirStructInit", .{});
}

fn zirFieldType(sema: *Sema, block: *Scope.Block, inst: zir.Inst.Index) InnerError!*Inst {
    const inst_data = sema.code.instructions.items(.data)[inst].pl_node;
    const src = inst_data.src();
    return sema.mod.fail(&block.base, src, "TODO: Sema.zirFieldType", .{});
}

fn requireFunctionBlock(sema: *Sema, block: *Scope.Block, src: LazySrcLoc) !void {
    if (sema.func == null) {
        return sema.mod.fail(&block.base, src, "instruction illegal outside function body", .{});
    }
}

fn requireRuntimeBlock(sema: *Sema, block: *Scope.Block, src: LazySrcLoc) !void {
    if (block.is_comptime) {
        return sema.mod.fail(&block.base, src, "unable to resolve comptime value", .{});
    }
    try sema.requireFunctionBlock(block, src);
}

fn validateVarType(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, ty: Type) !void {
    if (!ty.isValidVarType(false)) {
        return sema.mod.fail(&block.base, src, "variable of type '{}' must be const or comptime", .{ty});
    }
}

pub const PanicId = enum {
    unreach,
    unwrap_null,
    unwrap_errunion,
    invalid_error_code,
};

fn addSafetyCheck(sema: *Sema, parent_block: *Scope.Block, ok: *Inst, panic_id: PanicId) !void {
    const block_inst = try sema.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = Type.initTag(.void),
            .src = ok.src,
        },
        .body = .{
            .instructions = try sema.arena.alloc(*Inst, 1), // Only need space for the condbr.
        },
    };

    const ok_body: ir.Body = .{
        .instructions = try sema.arena.alloc(*Inst, 1), // Only need space for the br_void.
    };
    const br_void = try sema.arena.create(Inst.BrVoid);
    br_void.* = .{
        .base = .{
            .tag = .br_void,
            .ty = Type.initTag(.noreturn),
            .src = ok.src,
        },
        .block = block_inst,
    };
    ok_body.instructions[0] = &br_void.base;

    var fail_block: Scope.Block = .{
        .parent = parent_block,
        .sema = sema,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
    };

    defer fail_block.instructions.deinit(sema.gpa);

    _ = try sema.safetyPanic(&fail_block, ok.src, panic_id);

    const fail_body: ir.Body = .{ .instructions = try sema.arena.dupe(*Inst, fail_block.instructions.items) };

    const condbr = try sema.arena.create(Inst.CondBr);
    condbr.* = .{
        .base = .{
            .tag = .condbr,
            .ty = Type.initTag(.noreturn),
            .src = ok.src,
        },
        .condition = ok,
        .then_body = ok_body,
        .else_body = fail_body,
    };
    block_inst.body.instructions[0] = &condbr.base;

    try parent_block.instructions.append(sema.gpa, &block_inst.base);
}

fn safetyPanic(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, panic_id: PanicId) !zir.Inst.Index {
    // TODO Once we have a panic function to call, call it here instead of breakpoint.
    _ = try block.addNoOp(src, Type.initTag(.void), .breakpoint);
    _ = try block.addNoOp(src, Type.initTag(.noreturn), .unreach);
    return always_noreturn;
}

fn emitBackwardBranch(sema: *Sema, block: *Scope.Block, src: LazySrcLoc) !void {
    sema.branch_count += 1;
    if (sema.branch_count > sema.branch_quota) {
        // TODO show the "called from here" stack
        return sema.mod.fail(&block.base, src, "evaluation exceeded {d} backwards branches", .{sema.branch_quota});
    }
}

fn namedFieldPtr(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    object_ptr: *Inst,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
) InnerError!*Inst {
    const mod = sema.mod;
    const arena = sema.arena;

    const elem_ty = switch (object_ptr.ty.zigTypeTag()) {
        .Pointer => object_ptr.ty.elemType(),
        else => return mod.fail(&block.base, object_ptr.src, "expected pointer, found '{}'", .{object_ptr.ty}),
    };
    switch (elem_ty.zigTypeTag()) {
        .Array => {
            if (mem.eql(u8, field_name, "len")) {
                return mod.constInst(arena, src, .{
                    .ty = Type.initTag(.single_const_pointer_to_comptime_int),
                    .val = try Value.Tag.ref_val.create(
                        arena,
                        try Value.Tag.int_u64.create(arena, elem_ty.arrayLen()),
                    ),
                });
            } else {
                return mod.fail(
                    &block.base,
                    field_name_src,
                    "no member named '{s}' in '{}'",
                    .{ field_name, elem_ty },
                );
            }
        },
        .Pointer => {
            const ptr_child = elem_ty.elemType();
            switch (ptr_child.zigTypeTag()) {
                .Array => {
                    if (mem.eql(u8, field_name, "len")) {
                        return mod.constInst(arena, src, .{
                            .ty = Type.initTag(.single_const_pointer_to_comptime_int),
                            .val = try Value.Tag.ref_val.create(
                                arena,
                                try Value.Tag.int_u64.create(arena, ptr_child.arrayLen()),
                            ),
                        });
                    } else {
                        return mod.fail(
                            &block.base,
                            field_name_src,
                            "no member named '{s}' in '{}'",
                            .{ field_name, elem_ty },
                        );
                    }
                },
                else => {},
            }
        },
        .Type => {
            _ = try sema.resolveConstValue(block, object_ptr.src, object_ptr);
            const result = try sema.analyzeLoad(block, src, object_ptr, object_ptr.src);
            const val = result.value().?;
            const child_type = try val.toType(arena);
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
                        return mod.fail(&block.base, src, "no error named '{s}' in '{}'", .{
                            field_name,
                            child_type,
                        });
                    } else (try mod.getErrorValue(field_name)).key;

                    return mod.constInst(arena, src, .{
                        .ty = try mod.simplePtrType(arena, child_type, false, .One),
                        .val = try Value.Tag.ref_val.create(
                            arena,
                            try Value.Tag.@"error".create(arena, .{
                                .name = name,
                            }),
                        ),
                    });
                },
                .Struct, .Opaque, .Union => {
                    if (child_type.getContainerScope()) |container_scope| {
                        if (mod.lookupDeclName(&container_scope.base, field_name)) |decl| {
                            if (!decl.is_pub and !(decl.container.file_scope == block.base.namespace().file_scope))
                                return mod.fail(&block.base, src, "'{s}' is private", .{field_name});
                            return sema.analyzeDeclRef(block, src, decl);
                        }

                        // TODO this will give false positives for structs inside the root file
                        if (container_scope.file_scope == mod.root_scope) {
                            return mod.fail(
                                &block.base,
                                src,
                                "root source file has no member named '{s}'",
                                .{field_name},
                            );
                        }
                    }
                    // TODO add note: declared here
                    const kw_name = switch (child_type.zigTypeTag()) {
                        .Struct => "struct",
                        .Opaque => "opaque",
                        .Union => "union",
                        else => unreachable,
                    };
                    return mod.fail(&block.base, src, "{s} '{}' has no member named '{s}'", .{
                        kw_name, child_type, field_name,
                    });
                },
                .Enum => {
                    if (child_type.getContainerScope()) |container_scope| {
                        if (mod.lookupDeclName(&container_scope.base, field_name)) |decl| {
                            if (!decl.is_pub and !(decl.container.file_scope == block.base.namespace().file_scope))
                                return mod.fail(&block.base, src, "'{s}' is private", .{field_name});
                            return sema.analyzeDeclRef(block, src, decl);
                        }
                    }
                    const field_index = child_type.enumFieldIndex(field_name) orelse {
                        const msg = msg: {
                            const msg = try mod.errMsg(
                                &block.base,
                                src,
                                "enum '{}' has no member named '{s}'",
                                .{ child_type, field_name },
                            );
                            errdefer msg.destroy(sema.gpa);
                            try mod.errNoteNonLazy(
                                child_type.declSrcLoc(),
                                msg,
                                "enum declared here",
                                .{},
                            );
                            break :msg msg;
                        };
                        return mod.failWithOwnedErrorMsg(&block.base, msg);
                    };
                    const field_index_u32 = @intCast(u32, field_index);
                    const enum_val = try Value.Tag.enum_field_index.create(arena, field_index_u32);
                    return mod.constInst(arena, src, .{
                        .ty = try mod.simplePtrType(arena, child_type, false, .One),
                        .val = try Value.Tag.ref_val.create(arena, enum_val),
                    });
                },
                else => return mod.fail(&block.base, src, "type '{}' has no members", .{child_type}),
            }
        },
        .Struct => return sema.analyzeStructFieldPtr(block, src, object_ptr, field_name, field_name_src, elem_ty),
        else => {},
    }
    return mod.fail(&block.base, src, "type '{}' does not support field access", .{elem_ty});
}

fn analyzeStructFieldPtr(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    struct_ptr: *Inst,
    field_name: []const u8,
    field_name_src: LazySrcLoc,
    elem_ty: Type,
) InnerError!*Inst {
    const mod = sema.mod;
    const arena = sema.arena;
    assert(elem_ty.zigTypeTag() == .Struct);

    const struct_obj = elem_ty.castTag(.@"struct").?.data;

    const field_index = struct_obj.fields.getIndex(field_name) orelse
        return sema.failWithBadFieldAccess(block, struct_obj, field_name_src, field_name);
    const field = struct_obj.fields.entries.items[field_index].value;
    const ptr_field_ty = try mod.simplePtrType(arena, field.ty, true, .One);
    // TODO comptime field access
    try sema.requireRuntimeBlock(block, src);
    return block.addStructFieldPtr(src, ptr_field_ty, struct_ptr, @intCast(u32, field_index));
}

fn elemPtr(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    array_ptr: *Inst,
    elem_index: *Inst,
    elem_index_src: LazySrcLoc,
) InnerError!*Inst {
    const array_ty = switch (array_ptr.ty.zigTypeTag()) {
        .Pointer => array_ptr.ty.elemType(),
        else => return sema.mod.fail(&block.base, array_ptr.src, "expected pointer, found '{}'", .{array_ptr.ty}),
    };
    if (!array_ty.isIndexable()) {
        return sema.mod.fail(&block.base, src, "array access of non-array type '{}'", .{array_ty});
    }
    if (array_ty.isSinglePointer() and array_ty.elemType().zigTypeTag() == .Array) {
        // we have to deref the ptr operand to get the actual array pointer
        const array_ptr_deref = try sema.analyzeLoad(block, src, array_ptr, array_ptr.src);
        return sema.elemPtrArray(block, src, array_ptr_deref, elem_index, elem_index_src);
    }
    if (array_ty.zigTypeTag() == .Array) {
        return sema.elemPtrArray(block, src, array_ptr, elem_index, elem_index_src);
    }

    return sema.mod.fail(&block.base, src, "TODO implement more analyze elemptr", .{});
}

fn elemPtrArray(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    array_ptr: *Inst,
    elem_index: *Inst,
    elem_index_src: LazySrcLoc,
) InnerError!*Inst {
    if (array_ptr.value()) |array_ptr_val| {
        if (elem_index.value()) |index_val| {
            // Both array pointer and index are compile-time known.
            const index_u64 = index_val.toUnsignedInt();
            // @intCast here because it would have been impossible to construct a value that
            // required a larger index.
            const elem_ptr = try array_ptr_val.elemPtr(sema.arena, @intCast(usize, index_u64));
            const pointee_type = array_ptr.ty.elemType().elemType();

            return sema.mod.constInst(sema.arena, src, .{
                .ty = try Type.Tag.single_const_pointer.create(sema.arena, pointee_type),
                .val = elem_ptr,
            });
        }
    }
    return sema.mod.fail(&block.base, src, "TODO implement more analyze elemptr for arrays", .{});
}

fn coerce(
    sema: *Sema,
    block: *Scope.Block,
    dest_type: Type,
    inst: *Inst,
    inst_src: LazySrcLoc,
) InnerError!*Inst {
    if (dest_type.tag() == .var_args_param) {
        return sema.coerceVarArgParam(block, inst);
    }
    // If the types are the same, we can return the operand.
    if (dest_type.eql(inst.ty))
        return inst;

    const in_memory_result = coerceInMemoryAllowed(dest_type, inst.ty);
    if (in_memory_result == .ok) {
        return sema.bitcast(block, dest_type, inst);
    }

    const mod = sema.mod;
    const arena = sema.arena;

    // undefined to anything
    if (inst.value()) |val| {
        if (val.isUndef() or inst.ty.zigTypeTag() == .Undefined) {
            return mod.constInst(arena, inst_src, .{ .ty = dest_type, .val = val });
        }
    }
    assert(inst.ty.zigTypeTag() != .Undefined);

    // T to E!T or E to E!T
    if (dest_type.tag() == .error_union) {
        return try sema.wrapErrorUnion(block, dest_type, inst);
    }

    // comptime known number to other number
    if (try sema.coerceNum(block, dest_type, inst)) |some|
        return some;

    const target = mod.getTarget();

    switch (dest_type.zigTypeTag()) {
        .Optional => {
            // null to ?T
            if (inst.ty.zigTypeTag() == .Null) {
                return mod.constInst(arena, inst_src, .{ .ty = dest_type, .val = Value.initTag(.null_value) });
            }

            // T to ?T
            var buf: Type.Payload.ElemType = undefined;
            const child_type = dest_type.optionalChild(&buf);
            if (child_type.eql(inst.ty)) {
                return sema.wrapOptional(block, dest_type, inst);
            } else if (try sema.coerceNum(block, child_type, inst)) |some| {
                return sema.wrapOptional(block, dest_type, some);
            }
        },
        .Pointer => {
            // Coercions where the source is a single pointer to an array.
            src_array_ptr: {
                if (!inst.ty.isSinglePointer()) break :src_array_ptr;
                const array_type = inst.ty.elemType();
                if (array_type.zigTypeTag() != .Array) break :src_array_ptr;
                const array_elem_type = array_type.elemType();
                if (inst.ty.isConstPtr() and !dest_type.isConstPtr()) break :src_array_ptr;
                if (inst.ty.isVolatilePtr() and !dest_type.isVolatilePtr()) break :src_array_ptr;

                const dst_elem_type = dest_type.elemType();
                switch (coerceInMemoryAllowed(dst_elem_type, array_elem_type)) {
                    .ok => {},
                    .no_match => break :src_array_ptr,
                }

                switch (dest_type.ptrSize()) {
                    .Slice => {
                        // *[N]T to []T
                        return sema.coerceArrayPtrToSlice(block, dest_type, inst);
                    },
                    .C => {
                        // *[N]T to [*c]T
                        return sema.coerceArrayPtrToMany(block, dest_type, inst);
                    },
                    .Many => {
                        // *[N]T to [*]T
                        // *[N:s]T to [*:s]T
                        const src_sentinel = array_type.sentinel();
                        const dst_sentinel = dest_type.sentinel();
                        if (src_sentinel == null and dst_sentinel == null)
                            return sema.coerceArrayPtrToMany(block, dest_type, inst);

                        if (src_sentinel) |src_s| {
                            if (dst_sentinel) |dst_s| {
                                if (src_s.eql(dst_s)) {
                                    return sema.coerceArrayPtrToMany(block, dest_type, inst);
                                }
                            }
                        }
                    },
                    .One => {},
                }
            }
        },
        .Int => {
            // integer widening
            if (inst.ty.zigTypeTag() == .Int) {
                assert(inst.value() == null); // handled above

                const dst_info = dest_type.intInfo(target);
                const src_info = inst.ty.intInfo(target);
                if ((src_info.signedness == dst_info.signedness and dst_info.bits >= src_info.bits) or
                    // small enough unsigned ints can get casted to large enough signed ints
                    (src_info.signedness == .signed and dst_info.signedness == .unsigned and dst_info.bits > src_info.bits))
                {
                    try sema.requireRuntimeBlock(block, inst_src);
                    return block.addUnOp(inst_src, dest_type, .intcast, inst);
                }
            }
        },
        .Float => {
            // float widening
            if (inst.ty.zigTypeTag() == .Float) {
                assert(inst.value() == null); // handled above

                const src_bits = inst.ty.floatBits(target);
                const dst_bits = dest_type.floatBits(target);
                if (dst_bits >= src_bits) {
                    try sema.requireRuntimeBlock(block, inst_src);
                    return block.addUnOp(inst_src, dest_type, .floatcast, inst);
                }
            }
        },
        .Enum => {
            // enum literal to enum
            if (inst.ty.zigTypeTag() == .EnumLiteral) {
                const val = try sema.resolveConstValue(block, inst_src, inst);
                const bytes = val.castTag(.enum_literal).?.data;
                const field_index = dest_type.enumFieldIndex(bytes) orelse {
                    const msg = msg: {
                        const msg = try mod.errMsg(
                            &block.base,
                            inst_src,
                            "enum '{}' has no field named '{s}'",
                            .{ dest_type, bytes },
                        );
                        errdefer msg.destroy(sema.gpa);
                        try mod.errNoteNonLazy(
                            dest_type.declSrcLoc(),
                            msg,
                            "enum declared here",
                            .{},
                        );
                        break :msg msg;
                    };
                    return mod.failWithOwnedErrorMsg(&block.base, msg);
                };
                return mod.constInst(arena, inst_src, .{
                    .ty = dest_type,
                    .val = try Value.Tag.enum_field_index.create(arena, @intCast(u32, field_index)),
                });
            }
        },
        else => {},
    }

    return mod.fail(&block.base, inst_src, "expected {}, found {}", .{ dest_type, inst.ty });
}

const InMemoryCoercionResult = enum {
    ok,
    no_match,
};

fn coerceInMemoryAllowed(dest_type: Type, src_type: Type) InMemoryCoercionResult {
    if (dest_type.eql(src_type))
        return .ok;

    // TODO: implement more of this function

    return .no_match;
}

fn coerceNum(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) InnerError!?*Inst {
    const val = inst.value() orelse return null;
    const src_zig_tag = inst.ty.zigTypeTag();
    const dst_zig_tag = dest_type.zigTypeTag();

    const target = sema.mod.getTarget();

    if (dst_zig_tag == .ComptimeInt or dst_zig_tag == .Int) {
        if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
            if (val.floatHasFraction()) {
                return sema.mod.fail(&block.base, inst.src, "fractional component prevents float value {} from being casted to type '{}'", .{ val, inst.ty });
            }
            return sema.mod.fail(&block.base, inst.src, "TODO float to int", .{});
        } else if (src_zig_tag == .Int or src_zig_tag == .ComptimeInt) {
            if (!val.intFitsInType(dest_type, target)) {
                return sema.mod.fail(&block.base, inst.src, "type {} cannot represent integer value {}", .{ inst.ty, val });
            }
            return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = val });
        }
    } else if (dst_zig_tag == .ComptimeFloat or dst_zig_tag == .Float) {
        if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
            const res = val.floatCast(sema.arena, dest_type, target) catch |err| switch (err) {
                error.Overflow => return sema.mod.fail(
                    &block.base,
                    inst.src,
                    "cast of value {} to type '{}' loses information",
                    .{ val, dest_type },
                ),
                error.OutOfMemory => return error.OutOfMemory,
            };
            return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = res });
        } else if (src_zig_tag == .Int or src_zig_tag == .ComptimeInt) {
            return sema.mod.fail(&block.base, inst.src, "TODO int to float", .{});
        }
    }
    return null;
}

fn coerceVarArgParam(sema: *Sema, block: *Scope.Block, inst: *Inst) !*Inst {
    switch (inst.ty.zigTypeTag()) {
        .ComptimeInt, .ComptimeFloat => return sema.mod.fail(&block.base, inst.src, "integer and float literals in var args function must be casted", .{}),
        else => {},
    }
    // TODO implement more of this function.
    return inst;
}

fn storePtr(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    ptr: *Inst,
    uncasted_value: *Inst,
) !void {
    if (ptr.ty.isConstPtr())
        return sema.mod.fail(&block.base, src, "cannot assign to constant", .{});

    const elem_ty = ptr.ty.elemType();
    const value = try sema.coerce(block, elem_ty, uncasted_value, src);
    if (elem_ty.onePossibleValue() != null)
        return;

    // TODO handle comptime pointer writes
    // TODO handle if the element type requires comptime

    try sema.requireRuntimeBlock(block, src);
    _ = try block.addBinOp(src, Type.initTag(.void), .store, ptr, value);
}

fn bitcast(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // Keep the comptime Value representation; take the new type.
        return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = val });
    }
    // TODO validate the type size and other compile errors
    try sema.requireRuntimeBlock(block, inst.src);
    return block.addUnOp(inst.src, dest_type, .bitcast, inst);
}

fn coerceArrayPtrToSlice(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // The comptime Value representation is compatible with both types.
        return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = val });
    }
    return sema.mod.fail(&block.base, inst.src, "TODO implement coerceArrayPtrToSlice runtime instruction", .{});
}

fn coerceArrayPtrToMany(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // The comptime Value representation is compatible with both types.
        return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = val });
    }
    return sema.mod.fail(&block.base, inst.src, "TODO implement coerceArrayPtrToMany runtime instruction", .{});
}

fn analyzeDeclVal(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, decl: *Decl) InnerError!*Inst {
    const decl_ref = try sema.analyzeDeclRef(block, src, decl);
    return sema.analyzeLoad(block, src, decl_ref, src);
}

fn analyzeDeclRef(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, decl: *Decl) InnerError!*Inst {
    _ = try sema.mod.declareDeclDependency(sema.owner_decl, decl);
    sema.mod.ensureDeclAnalyzed(decl) catch |err| {
        if (sema.func) |func| {
            func.state = .dependency_failure;
        } else {
            sema.owner_decl.analysis = .dependency_failure;
        }
        return err;
    };

    const decl_tv = try decl.typedValue();
    if (decl_tv.val.tag() == .variable) {
        return sema.analyzeVarRef(block, src, decl_tv);
    }
    return sema.mod.constInst(sema.arena, src, .{
        .ty = try sema.mod.simplePtrType(sema.arena, decl_tv.ty, false, .One),
        .val = try Value.Tag.decl_ref.create(sema.arena, decl),
    });
}

fn analyzeVarRef(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, tv: TypedValue) InnerError!*Inst {
    const variable = tv.val.castTag(.variable).?.data;

    const ty = try sema.mod.simplePtrType(sema.arena, tv.ty, variable.is_mutable, .One);
    if (!variable.is_mutable and !variable.is_extern) {
        return sema.mod.constInst(sema.arena, src, .{
            .ty = ty,
            .val = try Value.Tag.ref_val.create(sema.arena, variable.init),
        });
    }

    try sema.requireRuntimeBlock(block, src);
    const inst = try sema.arena.create(Inst.VarPtr);
    inst.* = .{
        .base = .{
            .tag = .varptr,
            .ty = ty,
            .src = src,
        },
        .variable = variable,
    };
    try block.instructions.append(sema.gpa, &inst.base);
    return &inst.base;
}

fn analyzeRef(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    operand: *Inst,
) InnerError!*Inst {
    const ptr_type = try sema.mod.simplePtrType(sema.arena, operand.ty, false, .One);

    if (operand.value()) |val| {
        return sema.mod.constInst(sema.arena, src, .{
            .ty = ptr_type,
            .val = try Value.Tag.ref_val.create(sema.arena, val),
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, ptr_type, .ref, operand);
}

fn analyzeLoad(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    ptr: *Inst,
    ptr_src: LazySrcLoc,
) InnerError!*Inst {
    const elem_ty = switch (ptr.ty.zigTypeTag()) {
        .Pointer => ptr.ty.elemType(),
        else => return sema.mod.fail(&block.base, ptr_src, "expected pointer, found '{}'", .{ptr.ty}),
    };
    if (ptr.value()) |val| {
        return sema.mod.constInst(sema.arena, src, .{
            .ty = elem_ty,
            .val = try val.pointerDeref(sema.arena),
        });
    }

    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, elem_ty, .load, ptr);
}

fn analyzeIsNull(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    operand: *Inst,
    invert_logic: bool,
) InnerError!*Inst {
    if (operand.value()) |opt_val| {
        const is_null = opt_val.isNull();
        const bool_value = if (invert_logic) !is_null else is_null;
        return sema.mod.constBool(sema.arena, src, bool_value);
    }
    try sema.requireRuntimeBlock(block, src);
    const inst_tag: Inst.Tag = if (invert_logic) .is_non_null else .is_null;
    return block.addUnOp(src, Type.initTag(.bool), inst_tag, operand);
}

fn analyzeIsErr(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, operand: *Inst) InnerError!*Inst {
    const ot = operand.ty.zigTypeTag();
    if (ot != .ErrorSet and ot != .ErrorUnion) return sema.mod.constBool(sema.arena, src, false);
    if (ot == .ErrorSet) return sema.mod.constBool(sema.arena, src, true);
    assert(ot == .ErrorUnion);
    if (operand.value()) |err_union| {
        return sema.mod.constBool(sema.arena, src, err_union.getError() != null);
    }
    try sema.requireRuntimeBlock(block, src);
    return block.addUnOp(src, Type.initTag(.bool), .is_err, operand);
}

fn analyzeSlice(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    array_ptr: *Inst,
    start: *Inst,
    end_opt: ?*Inst,
    sentinel_opt: ?*Inst,
    sentinel_src: LazySrcLoc,
) InnerError!*Inst {
    const ptr_child = switch (array_ptr.ty.zigTypeTag()) {
        .Pointer => array_ptr.ty.elemType(),
        else => return sema.mod.fail(&block.base, src, "expected pointer, found '{}'", .{array_ptr.ty}),
    };

    var array_type = ptr_child;
    const elem_type = switch (ptr_child.zigTypeTag()) {
        .Array => ptr_child.elemType(),
        .Pointer => blk: {
            if (ptr_child.isSinglePointer()) {
                if (ptr_child.elemType().zigTypeTag() == .Array) {
                    array_type = ptr_child.elemType();
                    break :blk ptr_child.elemType().elemType();
                }

                return sema.mod.fail(&block.base, src, "slice of single-item pointer", .{});
            }
            break :blk ptr_child.elemType();
        },
        else => return sema.mod.fail(&block.base, src, "slice of non-array type '{}'", .{ptr_child}),
    };

    const slice_sentinel = if (sentinel_opt) |sentinel| blk: {
        const casted = try sema.coerce(block, elem_type, sentinel, sentinel.src);
        break :blk try sema.resolveConstValue(block, sentinel_src, casted);
    } else null;

    var return_ptr_size: std.builtin.TypeInfo.Pointer.Size = .Slice;
    var return_elem_type = elem_type;
    if (end_opt) |end| {
        if (end.value()) |end_val| {
            if (start.value()) |start_val| {
                const start_u64 = start_val.toUnsignedInt();
                const end_u64 = end_val.toUnsignedInt();
                if (start_u64 > end_u64) {
                    return sema.mod.fail(&block.base, src, "out of bounds slice", .{});
                }

                const len = end_u64 - start_u64;
                const array_sentinel = if (array_type.zigTypeTag() == .Array and end_u64 == array_type.arrayLen())
                    array_type.sentinel()
                else
                    slice_sentinel;
                return_elem_type = try sema.mod.arrayType(sema.arena, len, array_sentinel, elem_type);
                return_ptr_size = .One;
            }
        }
    }
    const return_type = try sema.mod.ptrType(
        sema.arena,
        return_elem_type,
        if (end_opt == null) slice_sentinel else null,
        0, // TODO alignment
        0,
        0,
        !ptr_child.isConstPtr(),
        ptr_child.isAllowzeroPtr(),
        ptr_child.isVolatilePtr(),
        return_ptr_size,
    );

    return sema.mod.fail(&block.base, src, "TODO implement analysis of slice", .{});
}

fn analyzeImport(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, target_string: []const u8) !*Scope.File {
    const cur_pkg = block.getFileScope().pkg;
    const cur_pkg_dir_path = cur_pkg.root_src_directory.path orelse ".";
    const found_pkg = cur_pkg.table.get(target_string);

    const resolved_path = if (found_pkg) |pkg|
        try std.fs.path.resolve(sema.gpa, &[_][]const u8{ pkg.root_src_directory.path orelse ".", pkg.root_src_path })
    else
        try std.fs.path.resolve(sema.gpa, &[_][]const u8{ cur_pkg_dir_path, target_string });
    errdefer sema.gpa.free(resolved_path);

    if (sema.mod.import_table.get(resolved_path)) |cached_import| {
        sema.gpa.free(resolved_path);
        return cached_import;
    }

    if (found_pkg == null) {
        const resolved_root_path = try std.fs.path.resolve(sema.gpa, &[_][]const u8{cur_pkg_dir_path});
        defer sema.gpa.free(resolved_root_path);

        if (!mem.startsWith(u8, resolved_path, resolved_root_path)) {
            return error.ImportOutsidePkgPath;
        }
    }

    // TODO Scope.Container arena for ty and sub_file_path
    const file_scope = try sema.gpa.create(Scope.File);
    errdefer sema.gpa.destroy(file_scope);
    const struct_ty = try Type.Tag.empty_struct.create(sema.gpa, &file_scope.root_container);
    errdefer sema.gpa.destroy(struct_ty.castTag(.empty_struct).?);

    const container_name_hash: Scope.NameHash = if (found_pkg) |pkg|
        pkg.namespace_hash
    else
        std.zig.hashName(cur_pkg.namespace_hash, "/", resolved_path);

    file_scope.* = .{
        .sub_file_path = resolved_path,
        .source = .{ .unloaded = {} },
        .tree = undefined,
        .status = .never_loaded,
        .pkg = found_pkg orelse cur_pkg,
        .root_container = .{
            .file_scope = file_scope,
            .decls = .{},
            .ty = struct_ty,
            .parent_name_hash = container_name_hash,
        },
    };
    sema.mod.analyzeContainer(&file_scope.root_container) catch |err| switch (err) {
        error.AnalysisFail => {
            assert(sema.mod.comp.totalErrorCount() != 0);
        },
        else => |e| return e,
    };
    try sema.mod.import_table.put(sema.gpa, file_scope.sub_file_path, file_scope);
    return file_scope;
}

/// Asserts that lhs and rhs types are both numeric.
fn cmpNumeric(
    sema: *Sema,
    block: *Scope.Block,
    src: LazySrcLoc,
    lhs: *Inst,
    rhs: *Inst,
    op: std.math.CompareOperator,
) InnerError!*Inst {
    assert(lhs.ty.isNumeric());
    assert(rhs.ty.isNumeric());

    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();

    if (lhs_ty_tag == .Vector and rhs_ty_tag == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return sema.mod.fail(&block.base, src, "vector length mismatch: {d} and {d}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return sema.mod.fail(&block.base, src, "TODO implement support for vectors in cmpNumeric", .{});
    } else if (lhs_ty_tag == .Vector or rhs_ty_tag == .Vector) {
        return sema.mod.fail(&block.base, src, "mixed scalar and vector operands to comparison operator: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    if (lhs.value()) |lhs_val| {
        if (rhs.value()) |rhs_val| {
            return sema.mod.constBool(sema.arena, src, Value.compare(lhs_val, op, rhs_val));
        }
    }

    // TODO handle comparisons against lazy zero values
    // Some values can be compared against zero without being runtime known or without forcing
    // a full resolution of their value, for example `@sizeOf(@Frame(function))` is known to
    // always be nonzero, and we benefit from not forcing the full evaluation and stack frame layout
    // of this function if we don't need to.

    // It must be a runtime comparison.
    try sema.requireRuntimeBlock(block, src);
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
        const dest_type = x: {
            if (lhs_ty_tag == .ComptimeFloat) {
                break :x rhs.ty;
            } else if (rhs_ty_tag == .ComptimeFloat) {
                break :x lhs.ty;
            }
            if (lhs.ty.floatBits(target) >= rhs.ty.floatBits(target)) {
                break :x lhs.ty;
            } else {
                break :x rhs.ty;
            }
        };
        const casted_lhs = try sema.coerce(block, dest_type, lhs, lhs.src);
        const casted_rhs = try sema.coerce(block, dest_type, rhs, rhs.src);
        return block.addBinOp(src, dest_type, Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
    }
    // For mixed unsigned integer sizes, implicit cast both operands to the larger integer.
    // For mixed signed and unsigned integers, implicit cast both operands to a signed
    // integer with + 1 bit.
    // For mixed floats and integers, extract the integer part from the float, cast that to
    // a signed integer with mantissa bits + 1, and if there was any non-integral part of the float,
    // add/subtract 1.
    const lhs_is_signed = if (lhs.value()) |lhs_val|
        lhs_val.compareWithZero(.lt)
    else
        (lhs.ty.isFloat() or lhs.ty.isSignedInt());
    const rhs_is_signed = if (rhs.value()) |rhs_val|
        rhs_val.compareWithZero(.lt)
    else
        (rhs.ty.isFloat() or rhs.ty.isSignedInt());
    const dest_int_is_signed = lhs_is_signed or rhs_is_signed;

    var dest_float_type: ?Type = null;

    var lhs_bits: usize = undefined;
    if (lhs.value()) |lhs_val| {
        if (lhs_val.isUndef())
            return sema.mod.constUndef(sema.arena, src, Type.initTag(.bool));
        const is_unsigned = if (lhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try lhs_val.toBigInt(&bigint_space).toManaged(sema.gpa);
            defer bigint.deinit();
            const zcmp = lhs_val.orderAgainstZero();
            if (lhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return sema.mod.constBool(sema.arena, src, false),
                    .neq => return sema.mod.constBool(sema.arena, src, true),
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
        dest_float_type = lhs.ty;
    } else {
        const int_info = lhs.ty.intInfo(target);
        lhs_bits = int_info.bits + @boolToInt(int_info.signedness == .unsigned and dest_int_is_signed);
    }

    var rhs_bits: usize = undefined;
    if (rhs.value()) |rhs_val| {
        if (rhs_val.isUndef())
            return sema.mod.constUndef(sema.arena, src, Type.initTag(.bool));
        const is_unsigned = if (rhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try rhs_val.toBigInt(&bigint_space).toManaged(sema.gpa);
            defer bigint.deinit();
            const zcmp = rhs_val.orderAgainstZero();
            if (rhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return sema.mod.constBool(sema.arena, src, false),
                    .neq => return sema.mod.constBool(sema.arena, src, true),
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
        dest_float_type = rhs.ty;
    } else {
        const int_info = rhs.ty.intInfo(target);
        rhs_bits = int_info.bits + @boolToInt(int_info.signedness == .unsigned and dest_int_is_signed);
    }

    const dest_type = if (dest_float_type) |ft| ft else blk: {
        const max_bits = std.math.max(lhs_bits, rhs_bits);
        const casted_bits = std.math.cast(u16, max_bits) catch |err| switch (err) {
            error.Overflow => return sema.mod.fail(&block.base, src, "{d} exceeds maximum integer bit count", .{max_bits}),
        };
        const signedness: std.builtin.Signedness = if (dest_int_is_signed) .signed else .unsigned;
        break :blk try Module.makeIntType(sema.arena, signedness, casted_bits);
    };
    const casted_lhs = try sema.coerce(block, dest_type, lhs, lhs.src);
    const casted_rhs = try sema.coerce(block, dest_type, rhs, rhs.src);

    return block.addBinOp(src, Type.initTag(.bool), Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
}

fn wrapOptional(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        return sema.mod.constInst(sema.arena, inst.src, .{ .ty = dest_type, .val = val });
    }

    try sema.requireRuntimeBlock(block, inst.src);
    return block.addUnOp(inst.src, dest_type, .wrap_optional, inst);
}

fn wrapErrorUnion(sema: *Sema, block: *Scope.Block, dest_type: Type, inst: *Inst) !*Inst {
    // TODO deal with inferred error sets
    const err_union = dest_type.castTag(.error_union).?;
    if (inst.value()) |val| {
        const to_wrap = if (inst.ty.zigTypeTag() != .ErrorSet) blk: {
            _ = try sema.coerce(block, err_union.data.payload, inst, inst.src);
            break :blk val;
        } else switch (err_union.data.error_set.tag()) {
            .anyerror => val,
            .error_set_single => blk: {
                const expected_name = val.castTag(.@"error").?.data.name;
                const n = err_union.data.error_set.castTag(.error_set_single).?.data;
                if (!mem.eql(u8, expected_name, n)) {
                    return sema.mod.fail(
                        &block.base,
                        inst.src,
                        "expected type '{}', found type '{}'",
                        .{ err_union.data.error_set, inst.ty },
                    );
                }
                break :blk val;
            },
            .error_set => blk: {
                const expected_name = val.castTag(.@"error").?.data.name;
                const error_set = err_union.data.error_set.castTag(.error_set).?.data;
                const names = error_set.names_ptr[0..error_set.names_len];
                // TODO this is O(N). I'm putting off solving this until we solve inferred
                // error sets at the same time.
                const found = for (names) |name| {
                    if (mem.eql(u8, expected_name, name)) break true;
                } else false;
                if (!found) {
                    return sema.mod.fail(
                        &block.base,
                        inst.src,
                        "expected type '{}', found type '{}'",
                        .{ err_union.data.error_set, inst.ty },
                    );
                }
                break :blk val;
            },
            else => unreachable,
        };

        return sema.mod.constInst(sema.arena, inst.src, .{
            .ty = dest_type,
            // creating a SubValue for the error_union payload
            .val = try Value.Tag.error_union.create(
                sema.arena,
                to_wrap,
            ),
        });
    }

    try sema.requireRuntimeBlock(block, inst.src);

    // we are coercing from E to E!T
    if (inst.ty.zigTypeTag() == .ErrorSet) {
        var coerced = try sema.coerce(block, err_union.data.error_set, inst, inst.src);
        return block.addUnOp(inst.src, dest_type, .wrap_errunion_err, coerced);
    } else {
        var coerced = try sema.coerce(block, err_union.data.payload, inst, inst.src);
        return block.addUnOp(inst.src, dest_type, .wrap_errunion_payload, coerced);
    }
}

fn resolvePeerTypes(sema: *Sema, block: *Scope.Block, src: LazySrcLoc, instructions: []*Inst) !Type {
    if (instructions.len == 0)
        return Type.initTag(.noreturn);

    if (instructions.len == 1)
        return instructions[0].ty;

    const target = sema.mod.getTarget();

    var chosen = instructions[0];
    for (instructions[1..]) |candidate| {
        if (candidate.ty.eql(chosen.ty))
            continue;
        if (candidate.ty.zigTypeTag() == .NoReturn)
            continue;
        if (chosen.ty.zigTypeTag() == .NoReturn) {
            chosen = candidate;
            continue;
        }
        if (candidate.ty.zigTypeTag() == .Undefined)
            continue;
        if (chosen.ty.zigTypeTag() == .Undefined) {
            chosen = candidate;
            continue;
        }
        if (chosen.ty.isInt() and
            candidate.ty.isInt() and
            chosen.ty.isSignedInt() == candidate.ty.isSignedInt())
        {
            if (chosen.ty.intInfo(target).bits < candidate.ty.intInfo(target).bits) {
                chosen = candidate;
            }
            continue;
        }
        if (chosen.ty.isFloat() and candidate.ty.isFloat()) {
            if (chosen.ty.floatBits(target) < candidate.ty.floatBits(target)) {
                chosen = candidate;
            }
            continue;
        }

        if (chosen.ty.zigTypeTag() == .ComptimeInt and candidate.ty.isInt()) {
            chosen = candidate;
            continue;
        }

        if (chosen.ty.isInt() and candidate.ty.zigTypeTag() == .ComptimeInt) {
            continue;
        }

        // TODO error notes pointing out each type
        return sema.mod.fail(&block.base, src, "incompatible types: '{}' and '{}'", .{ chosen.ty, candidate.ty });
    }

    return chosen.ty;
}
