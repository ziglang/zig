//! Semantic analysis of ZIR instructions.
//! This file operates on a `Module` instance, transforming untyped ZIR
//! instructions into semantically-analyzed IR instructions. It does type
//! checking, comptime control flow, and safety-check generation. This is the
//! the heart of the Zig compiler.
//! When deciding if something goes into this file or into Module, here is a
//! guiding principle: if it has to do with (untyped) ZIR instructions, it goes
//! here. If the analysis operates on typed IR instructions, it goes in Module.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.sema);

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

pub fn analyzeInst(mod: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Inst {
    switch (old_inst.tag) {
        .alloc => return zirAlloc(mod, scope, old_inst.castTag(.alloc).?),
        .alloc_mut => return zirAllocMut(mod, scope, old_inst.castTag(.alloc_mut).?),
        .alloc_inferred => return zirAllocInferred(mod, scope, old_inst.castTag(.alloc_inferred).?, .inferred_alloc_const),
        .alloc_inferred_mut => return zirAllocInferred(mod, scope, old_inst.castTag(.alloc_inferred_mut).?, .inferred_alloc_mut),
        .arg => return zirArg(mod, scope, old_inst.castTag(.arg).?),
        .bitcast_ref => return zirBitcastRef(mod, scope, old_inst.castTag(.bitcast_ref).?),
        .bitcast_result_ptr => return zirBitcastResultPtr(mod, scope, old_inst.castTag(.bitcast_result_ptr).?),
        .block => return zirBlock(mod, scope, old_inst.castTag(.block).?, false),
        .block_comptime => return zirBlock(mod, scope, old_inst.castTag(.block_comptime).?, true),
        .block_flat => return zirBlockFlat(mod, scope, old_inst.castTag(.block_flat).?, false),
        .block_comptime_flat => return zirBlockFlat(mod, scope, old_inst.castTag(.block_comptime_flat).?, true),
        .@"break" => return zirBreak(mod, scope, old_inst.castTag(.@"break").?),
        .breakpoint => return zirBreakpoint(mod, scope, old_inst.castTag(.breakpoint).?),
        .break_void => return zirBreakVoid(mod, scope, old_inst.castTag(.break_void).?),
        .call => return zirCall(mod, scope, old_inst.castTag(.call).?),
        .coerce_result_ptr => return zirCoerceResultPtr(mod, scope, old_inst.castTag(.coerce_result_ptr).?),
        .compile_error => return zirCompileError(mod, scope, old_inst.castTag(.compile_error).?),
        .compile_log => return zirCompileLog(mod, scope, old_inst.castTag(.compile_log).?),
        .@"const" => return zirConst(mod, scope, old_inst.castTag(.@"const").?),
        .dbg_stmt => return zirDbgStmt(mod, scope, old_inst.castTag(.dbg_stmt).?),
        .decl_ref => return zirDeclRef(mod, scope, old_inst.castTag(.decl_ref).?),
        .decl_ref_str => return zirDeclRefStr(mod, scope, old_inst.castTag(.decl_ref_str).?),
        .decl_val => return zirDeclVal(mod, scope, old_inst.castTag(.decl_val).?),
        .ensure_result_used => return zirEnsureResultUsed(mod, scope, old_inst.castTag(.ensure_result_used).?),
        .ensure_result_non_error => return zirEnsureResultNonError(mod, scope, old_inst.castTag(.ensure_result_non_error).?),
        .indexable_ptr_len => return zirIndexablePtrLen(mod, scope, old_inst.castTag(.indexable_ptr_len).?),
        .ref => return zirRef(mod, scope, old_inst.castTag(.ref).?),
        .resolve_inferred_alloc => return zirResolveInferredAlloc(mod, scope, old_inst.castTag(.resolve_inferred_alloc).?),
        .ret_ptr => return zirRetPtr(mod, scope, old_inst.castTag(.ret_ptr).?),
        .ret_type => return zirRetType(mod, scope, old_inst.castTag(.ret_type).?),
        .store_to_block_ptr => return zirStoreToBlockPtr(mod, scope, old_inst.castTag(.store_to_block_ptr).?),
        .store_to_inferred_ptr => return zirStoreToInferredPtr(mod, scope, old_inst.castTag(.store_to_inferred_ptr).?),
        .single_const_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.single_const_ptr_type).?, false, .One),
        .single_mut_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.single_mut_ptr_type).?, true, .One),
        .many_const_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.many_const_ptr_type).?, false, .Many),
        .many_mut_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.many_mut_ptr_type).?, true, .Many),
        .c_const_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.c_const_ptr_type).?, false, .C),
        .c_mut_ptr_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.c_mut_ptr_type).?, true, .C),
        .const_slice_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.const_slice_type).?, false, .Slice),
        .mut_slice_type => return zirSimplePtrType(mod, scope, old_inst.castTag(.mut_slice_type).?, true, .Slice),
        .ptr_type => return zirPtrType(mod, scope, old_inst.castTag(.ptr_type).?),
        .store => return zirStore(mod, scope, old_inst.castTag(.store).?),
        .set_eval_branch_quota => return zirSetEvalBranchQuota(mod, scope, old_inst.castTag(.set_eval_branch_quota).?),
        .str => return zirStr(mod, scope, old_inst.castTag(.str).?),
        .int => return zirInt(mod, scope, old_inst.castTag(.int).?),
        .int_type => return zirIntType(mod, scope, old_inst.castTag(.int_type).?),
        .loop => return zirLoop(mod, scope, old_inst.castTag(.loop).?),
        .param_type => return zirParamType(mod, scope, old_inst.castTag(.param_type).?),
        .ptrtoint => return zirPtrtoint(mod, scope, old_inst.castTag(.ptrtoint).?),
        .field_ptr => return zirFieldPtr(mod, scope, old_inst.castTag(.field_ptr).?),
        .field_val => return zirFieldVal(mod, scope, old_inst.castTag(.field_val).?),
        .field_ptr_named => return zirFieldPtrNamed(mod, scope, old_inst.castTag(.field_ptr_named).?),
        .field_val_named => return zirFieldValNamed(mod, scope, old_inst.castTag(.field_val_named).?),
        .deref => return zirDeref(mod, scope, old_inst.castTag(.deref).?),
        .as => return zirAs(mod, scope, old_inst.castTag(.as).?),
        .@"asm" => return zirAsm(mod, scope, old_inst.castTag(.@"asm").?),
        .unreachable_safe => return zirUnreachable(mod, scope, old_inst.castTag(.unreachable_safe).?, true),
        .unreachable_unsafe => return zirUnreachable(mod, scope, old_inst.castTag(.unreachable_unsafe).?, false),
        .@"return" => return zirReturn(mod, scope, old_inst.castTag(.@"return").?),
        .return_void => return zirReturnVoid(mod, scope, old_inst.castTag(.return_void).?),
        .@"fn" => return zirFn(mod, scope, old_inst.castTag(.@"fn").?),
        .@"export" => return zirExport(mod, scope, old_inst.castTag(.@"export").?),
        .primitive => return zirPrimitive(mod, scope, old_inst.castTag(.primitive).?),
        .fntype => return zirFnType(mod, scope, old_inst.castTag(.fntype).?),
        .intcast => return zirIntcast(mod, scope, old_inst.castTag(.intcast).?),
        .bitcast => return zirBitcast(mod, scope, old_inst.castTag(.bitcast).?),
        .floatcast => return zirFloatcast(mod, scope, old_inst.castTag(.floatcast).?),
        .elem_ptr => return zirElemPtr(mod, scope, old_inst.castTag(.elem_ptr).?),
        .elem_val => return zirElemVal(mod, scope, old_inst.castTag(.elem_val).?),
        .add => return zirArithmetic(mod, scope, old_inst.castTag(.add).?),
        .addwrap => return zirArithmetic(mod, scope, old_inst.castTag(.addwrap).?),
        .sub => return zirArithmetic(mod, scope, old_inst.castTag(.sub).?),
        .subwrap => return zirArithmetic(mod, scope, old_inst.castTag(.subwrap).?),
        .mul => return zirArithmetic(mod, scope, old_inst.castTag(.mul).?),
        .mulwrap => return zirArithmetic(mod, scope, old_inst.castTag(.mulwrap).?),
        .div => return zirArithmetic(mod, scope, old_inst.castTag(.div).?),
        .mod_rem => return zirArithmetic(mod, scope, old_inst.castTag(.mod_rem).?),
        .array_cat => return zirArrayCat(mod, scope, old_inst.castTag(.array_cat).?),
        .array_mul => return zirArrayMul(mod, scope, old_inst.castTag(.array_mul).?),
        .bit_and => return zirBitwise(mod, scope, old_inst.castTag(.bit_and).?),
        .bit_not => return zirBitNot(mod, scope, old_inst.castTag(.bit_not).?),
        .bit_or => return zirBitwise(mod, scope, old_inst.castTag(.bit_or).?),
        .xor => return zirBitwise(mod, scope, old_inst.castTag(.xor).?),
        .shl => return zirShl(mod, scope, old_inst.castTag(.shl).?),
        .shr => return zirShr(mod, scope, old_inst.castTag(.shr).?),
        .cmp_lt => return zirCmp(mod, scope, old_inst.castTag(.cmp_lt).?, .lt),
        .cmp_lte => return zirCmp(mod, scope, old_inst.castTag(.cmp_lte).?, .lte),
        .cmp_eq => return zirCmp(mod, scope, old_inst.castTag(.cmp_eq).?, .eq),
        .cmp_gte => return zirCmp(mod, scope, old_inst.castTag(.cmp_gte).?, .gte),
        .cmp_gt => return zirCmp(mod, scope, old_inst.castTag(.cmp_gt).?, .gt),
        .cmp_neq => return zirCmp(mod, scope, old_inst.castTag(.cmp_neq).?, .neq),
        .condbr => return zirCondbr(mod, scope, old_inst.castTag(.condbr).?),
        .is_null => return zirIsNull(mod, scope, old_inst.castTag(.is_null).?, false),
        .is_non_null => return zirIsNull(mod, scope, old_inst.castTag(.is_non_null).?, true),
        .is_null_ptr => return zirIsNullPtr(mod, scope, old_inst.castTag(.is_null_ptr).?, false),
        .is_non_null_ptr => return zirIsNullPtr(mod, scope, old_inst.castTag(.is_non_null_ptr).?, true),
        .is_err => return zirIsErr(mod, scope, old_inst.castTag(.is_err).?),
        .is_err_ptr => return zirIsErrPtr(mod, scope, old_inst.castTag(.is_err_ptr).?),
        .bool_not => return zirBoolNot(mod, scope, old_inst.castTag(.bool_not).?),
        .typeof => return zirTypeof(mod, scope, old_inst.castTag(.typeof).?),
        .typeof_peer => return zirTypeofPeer(mod, scope, old_inst.castTag(.typeof_peer).?),
        .optional_type => return zirOptionalType(mod, scope, old_inst.castTag(.optional_type).?),
        .optional_payload_safe => return zirOptionalPayload(mod, scope, old_inst.castTag(.optional_payload_safe).?, true),
        .optional_payload_unsafe => return zirOptionalPayload(mod, scope, old_inst.castTag(.optional_payload_unsafe).?, false),
        .optional_payload_safe_ptr => return zirOptionalPayloadPtr(mod, scope, old_inst.castTag(.optional_payload_safe_ptr).?, true),
        .optional_payload_unsafe_ptr => return zirOptionalPayloadPtr(mod, scope, old_inst.castTag(.optional_payload_unsafe_ptr).?, false),
        .err_union_payload_safe => return zirErrUnionPayload(mod, scope, old_inst.castTag(.err_union_payload_safe).?, true),
        .err_union_payload_unsafe => return zirErrUnionPayload(mod, scope, old_inst.castTag(.err_union_payload_unsafe).?, false),
        .err_union_payload_safe_ptr => return zirErrUnionPayloadPtr(mod, scope, old_inst.castTag(.err_union_payload_safe_ptr).?, true),
        .err_union_payload_unsafe_ptr => return zirErrUnionPayloadPtr(mod, scope, old_inst.castTag(.err_union_payload_unsafe_ptr).?, false),
        .err_union_code => return zirErrUnionCode(mod, scope, old_inst.castTag(.err_union_code).?),
        .err_union_code_ptr => return zirErrUnionCodePtr(mod, scope, old_inst.castTag(.err_union_code_ptr).?),
        .ensure_err_payload_void => return zirEnsureErrPayloadVoid(mod, scope, old_inst.castTag(.ensure_err_payload_void).?),
        .array_type => return zirArrayType(mod, scope, old_inst.castTag(.array_type).?),
        .array_type_sentinel => return zirArrayTypeSentinel(mod, scope, old_inst.castTag(.array_type_sentinel).?),
        .enum_literal => return zirEnumLiteral(mod, scope, old_inst.castTag(.enum_literal).?),
        .merge_error_sets => return zirMergeErrorSets(mod, scope, old_inst.castTag(.merge_error_sets).?),
        .error_union_type => return zirErrorUnionType(mod, scope, old_inst.castTag(.error_union_type).?),
        .anyframe_type => return zirAnyframeType(mod, scope, old_inst.castTag(.anyframe_type).?),
        .error_set => return zirErrorSet(mod, scope, old_inst.castTag(.error_set).?),
        .slice => return zirSlice(mod, scope, old_inst.castTag(.slice).?),
        .slice_start => return zirSliceStart(mod, scope, old_inst.castTag(.slice_start).?),
        .import => return zirImport(mod, scope, old_inst.castTag(.import).?),
        .bool_and => return zirBoolOp(mod, scope, old_inst.castTag(.bool_and).?),
        .bool_or => return zirBoolOp(mod, scope, old_inst.castTag(.bool_or).?),
        .void_value => return mod.constVoid(scope, old_inst.src),
        .switchbr => return zirSwitchBr(mod, scope, old_inst.castTag(.switchbr).?),
        .switch_range => return zirSwitchRange(mod, scope, old_inst.castTag(.switch_range).?),

        .container_field_named,
        .container_field_typed,
        .container_field,
        .enum_type,
        .union_type,
        .struct_type,
        => return mod.fail(scope, old_inst.src, "TODO analyze container instructions", .{}),
    }
}

pub fn analyzeBody(mod: *Module, block: *Scope.Block, body: zir.Body) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (body.instructions) |src_inst| {
        const analyzed_inst = try analyzeInst(mod, &block.base, src_inst);
        try block.inst_table.putNoClobber(src_inst, analyzed_inst);
        if (analyzed_inst.ty.zigTypeTag() == .NoReturn) {
            break;
        }
    }
}

pub fn analyzeBodyValueAsType(
    mod: *Module,
    block_scope: *Scope.Block,
    zir_result_inst: *zir.Inst,
    body: zir.Body,
) !Type {
    try analyzeBody(mod, block_scope, body);
    const result_inst = block_scope.inst_table.get(zir_result_inst).?;
    const val = try mod.resolveConstValue(&block_scope.base, result_inst);
    return val.toType(block_scope.base.arena());
}

pub fn resolveInst(mod: *Module, scope: *Scope, zir_inst: *zir.Inst) InnerError!*Inst {
    const block = scope.cast(Scope.Block).?;
    return block.inst_table.get(zir_inst).?; // Instruction does not dominate all uses!
}

fn resolveConstString(mod: *Module, scope: *Scope, old_inst: *zir.Inst) ![]u8 {
    const new_inst = try resolveInst(mod, scope, old_inst);
    const wanted_type = Type.initTag(.const_slice_u8);
    const coerced_inst = try mod.coerce(scope, wanted_type, new_inst);
    const val = try mod.resolveConstValue(scope, coerced_inst);
    return val.toAllocatedBytes(scope.arena());
}

fn resolveType(mod: *Module, scope: *Scope, old_inst: *zir.Inst) !Type {
    const new_inst = try resolveInst(mod, scope, old_inst);
    const wanted_type = Type.initTag(.@"type");
    const coerced_inst = try mod.coerce(scope, wanted_type, new_inst);
    const val = try mod.resolveConstValue(scope, coerced_inst);
    return val.toType(scope.arena());
}

/// Appropriate to call when the coercion has already been done by result
/// location semantics. Asserts the value fits in the provided `Int` type.
/// Only supports `Int` types 64 bits or less.
fn resolveAlreadyCoercedInt(
    mod: *Module,
    scope: *Scope,
    old_inst: *zir.Inst,
    comptime Int: type,
) !Int {
    comptime assert(@typeInfo(Int).Int.bits <= 64);
    const new_inst = try resolveInst(mod, scope, old_inst);
    const val = try mod.resolveConstValue(scope, new_inst);
    switch (@typeInfo(Int).Int.signedness) {
        .signed => return @intCast(Int, val.toSignedInt()),
        .unsigned => return @intCast(Int, val.toUnsignedInt()),
    }
}

fn resolveInt(mod: *Module, scope: *Scope, old_inst: *zir.Inst, dest_type: Type) !u64 {
    const new_inst = try resolveInst(mod, scope, old_inst);
    const coerced = try mod.coerce(scope, dest_type, new_inst);
    const val = try mod.resolveConstValue(scope, coerced);

    return val.toUnsignedInt();
}

pub fn resolveInstConst(mod: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try resolveInst(mod, scope, old_inst);
    const val = try mod.resolveConstValue(scope, new_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = val,
    };
}

fn zirConst(mod: *Module, scope: *Scope, const_inst: *zir.Inst.Const) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // Move the TypedValue from old memory to new memory. This allows freeing the ZIR instructions
    // after analysis.
    const typed_value_copy = try const_inst.positionals.typed_value.copy(scope.arena());
    return mod.constInst(scope, const_inst.base.src, typed_value_copy);
}

fn analyzeConstInst(mod: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try analyzeInst(mod, scope, old_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = try mod.resolveConstValue(scope, new_inst),
    };
}

fn zirBitcastRef(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zir_sema.zirBitcastRef", .{});
}

fn zirBitcastResultPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zir_sema.zirBitcastResultPtr", .{});
}

fn zirCoerceResultPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirCoerceResultPtr", .{});
}

fn zirRetPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, ret_type, true, .One);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn zirRef(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeRef(scope, inst.base.src, operand);
}

fn zirRetType(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    return mod.constType(scope, inst.base.src, ret_type);
}

fn zirEnsureResultUsed(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    switch (operand.ty.zigTypeTag()) {
        .Void, .NoReturn => return mod.constVoid(scope, operand.src),
        else => return mod.fail(scope, operand.src, "expression value is ignored", .{}),
    }
}

fn zirEnsureResultNonError(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    switch (operand.ty.zigTypeTag()) {
        .ErrorSet, .ErrorUnion => return mod.fail(scope, operand.src, "error is discarded", .{}),
        else => return mod.constVoid(scope, operand.src),
    }
}

fn zirIndexablePtrLen(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const array_ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const elem_ty = array_ptr.ty.elemType();
    if (!elem_ty.isIndexable()) {
        const msg = msg: {
            const msg = try mod.errMsg(
                scope,
                inst.base.src,
                "type '{}' does not support indexing",
                .{elem_ty},
            );
            errdefer msg.destroy(mod.gpa);
            try mod.errNote(
                scope,
                inst.base.src,
                msg,
                "for loop operand must be an array, slice, tuple, or vector",
                .{},
            );
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(scope, msg);
    }
    const result_ptr = try mod.namedFieldPtr(scope, inst.base.src, array_ptr, "len", inst.base.src);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn zirAlloc(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const var_type = try resolveType(mod, scope, inst.positionals.operand);
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, var_type, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn zirAllocMut(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const var_type = try resolveType(mod, scope, inst.positionals.operand);
    try mod.validateVarType(scope, inst.base.src, var_type);
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, var_type, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn zirAllocInferred(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.NoOp,
    mut_tag: Type.Tag,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const val_payload = try scope.arena().create(Value.Payload.InferredAlloc);
    val_payload.* = .{
        .data = .{},
    };
    // `Module.constInst` does not add the instruction to the block because it is
    // not needed in the case of constant values. However here, we plan to "downgrade"
    // to a normal instruction when we hit `resolve_inferred_alloc`. So we append
    // to the block even though it is currently a `.constant`.
    const result = try mod.constInst(scope, inst.base.src, .{
        .ty = switch (mut_tag) {
            .inferred_alloc_const => Type.initTag(.inferred_alloc_const),
            .inferred_alloc_mut => Type.initTag(.inferred_alloc_mut),
            else => unreachable,
        },
        .val = Value.initPayload(&val_payload.base),
    });
    const block = try mod.requireFunctionBlock(scope, inst.base.src);
    try block.instructions.append(mod.gpa, result);
    return result;
}

fn zirResolveInferredAlloc(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.UnOp,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const ptr_val = ptr.castTag(.constant).?.val;
    const inferred_alloc = ptr_val.castTag(.inferred_alloc).?;
    const peer_inst_list = inferred_alloc.data.stored_inst_list.items;
    const final_elem_ty = try mod.resolvePeerTypes(scope, peer_inst_list);
    const var_is_mut = switch (ptr.ty.tag()) {
        .inferred_alloc_const => false,
        .inferred_alloc_mut => true,
        else => unreachable,
    };
    if (var_is_mut) {
        try mod.validateVarType(scope, inst.base.src, final_elem_ty);
    }
    const final_ptr_ty = try mod.simplePtrType(scope, inst.base.src, final_elem_ty, true, .One);

    // Change it to a normal alloc.
    ptr.ty = final_ptr_ty;
    ptr.tag = .alloc;

    return mod.constVoid(scope, inst.base.src);
}

fn zirStoreToBlockPtr(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.BinOp,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const value = try resolveInst(mod, scope, inst.positionals.rhs);
    const ptr_ty = try mod.simplePtrType(scope, inst.base.src, value.ty, true, .One);
    // TODO detect when this store should be done at compile-time. For example,
    // if expressions should force it when the condition is compile-time known.
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    const bitcasted_ptr = try mod.addUnOp(b, inst.base.src, ptr_ty, .bitcast, ptr);
    return mod.storePtr(scope, inst.base.src, bitcasted_ptr, value);
}

fn zirStoreToInferredPtr(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.BinOp,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const value = try resolveInst(mod, scope, inst.positionals.rhs);
    const inferred_alloc = ptr.castTag(.constant).?.val.castTag(.inferred_alloc).?;
    // Add the stored instruction to the set we will use to resolve peer types
    // for the inferred allocation.
    try inferred_alloc.data.stored_inst_list.append(scope.arena(), value);
    // Create a runtime bitcast instruction with exactly the type the pointer wants.
    const ptr_ty = try mod.simplePtrType(scope, inst.base.src, value.ty, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    const bitcasted_ptr = try mod.addUnOp(b, inst.base.src, ptr_ty, .bitcast, ptr);
    return mod.storePtr(scope, inst.base.src, bitcasted_ptr, value);
}

fn zirSetEvalBranchQuota(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.UnOp,
) InnerError!*Inst {
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const quota = try resolveAlreadyCoercedInt(mod, scope, inst.positionals.operand, u32);
    if (b.branch_quota.* < quota)
        b.branch_quota.* = quota;
    return mod.constVoid(scope, inst.base.src);
}

fn zirStore(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const value = try resolveInst(mod, scope, inst.positionals.rhs);
    return mod.storePtr(scope, inst.base.src, ptr, value);
}

fn zirParamType(mod: *Module, scope: *Scope, inst: *zir.Inst.ParamType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const fn_inst = try resolveInst(mod, scope, inst.positionals.func);
    const arg_index = inst.positionals.arg_index;

    const fn_ty: Type = switch (fn_inst.ty.zigTypeTag()) {
        .Fn => fn_inst.ty,
        .BoundFn => {
            return mod.fail(scope, fn_inst.src, "TODO implement zirParamType for method call syntax", .{});
        },
        else => {
            return mod.fail(scope, fn_inst.src, "expected function, found '{}'", .{fn_inst.ty});
        },
    };

    // TODO support C-style var args
    const param_count = fn_ty.fnParamLen();
    if (arg_index >= param_count) {
        return mod.fail(scope, inst.base.src, "arg index {d} out of bounds; '{}' has {d} argument(s)", .{
            arg_index,
            fn_ty,
            param_count,
        });
    }

    // TODO support generic functions
    const param_type = fn_ty.fnParamType(arg_index);
    return mod.constType(scope, inst.base.src, param_type);
}

fn zirStr(mod: *Module, scope: *Scope, str_inst: *zir.Inst.Str) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // The bytes references memory inside the ZIR module, which can get deallocated
    // after semantic analysis is complete. We need the memory to be in the new anonymous Decl's arena.
    var new_decl_arena = std.heap.ArenaAllocator.init(mod.gpa);
    errdefer new_decl_arena.deinit();
    const arena_bytes = try new_decl_arena.allocator.dupe(u8, str_inst.positionals.bytes);

    const decl_ty = try Type.Tag.array_u8_sentinel_0.create(&new_decl_arena.allocator, arena_bytes.len);
    const decl_val = try Value.Tag.bytes.create(&new_decl_arena.allocator, arena_bytes);

    const new_decl = try mod.createAnonymousDecl(scope, &new_decl_arena, .{
        .ty = decl_ty,
        .val = decl_val,
    });
    return mod.analyzeDeclRef(scope, str_inst.base.src, new_decl);
}

fn zirInt(mod: *Module, scope: *Scope, inst: *zir.Inst.Int) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    return mod.constIntBig(scope, inst.base.src, Type.initTag(.comptime_int), inst.positionals.int);
}

fn zirExport(mod: *Module, scope: *Scope, export_inst: *zir.Inst.Export) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const symbol_name = try resolveConstString(mod, scope, export_inst.positionals.symbol_name);
    const exported_decl = mod.lookupDeclName(scope, export_inst.positionals.decl_name) orelse
        return mod.fail(scope, export_inst.base.src, "decl '{s}' not found", .{export_inst.positionals.decl_name});
    try mod.analyzeExport(scope, export_inst.base.src, symbol_name, exported_decl);
    return mod.constVoid(scope, export_inst.base.src);
}

fn zirCompileError(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const msg = try resolveConstString(mod, scope, inst.positionals.operand);
    return mod.fail(scope, inst.base.src, "{s}", .{msg});
}

fn zirCompileLog(mod: *Module, scope: *Scope, inst: *zir.Inst.CompileLog) InnerError!*Inst {
    var managed = mod.compile_log_text.toManaged(mod.gpa);
    defer mod.compile_log_text = managed.moveToUnmanaged();
    const writer = managed.writer();

    for (inst.positionals.to_log) |arg_inst, i| {
        if (i != 0) try writer.print(", ", .{});

        const arg = try resolveInst(mod, scope, arg_inst);
        if (arg.value()) |val| {
            try writer.print("@as({}, {})", .{ arg.ty, val });
        } else {
            try writer.print("@as({}, [runtime value])", .{arg.ty});
        }
    }
    try writer.print("\n", .{});

    const gop = try mod.compile_log_decls.getOrPut(mod.gpa, scope.ownerDecl().?);
    if (!gop.found_existing) {
        gop.entry.value = .{
            .file_scope = scope.getFileScope(),
            .byte_offset = inst.base.src,
        };
    }
    return mod.constVoid(scope, inst.base.src);
}

fn zirArg(mod: *Module, scope: *Scope, inst: *zir.Inst.Arg) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    if (b.inlining) |inlining| {
        const param_index = inlining.param_index;
        inlining.param_index += 1;
        return inlining.casted_args[param_index];
    }
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const param_index = b.instructions.items.len;
    const param_count = fn_ty.fnParamLen();
    if (param_index >= param_count) {
        return mod.fail(scope, inst.base.src, "parameter index {d} outside list of length {d}", .{
            param_index,
            param_count,
        });
    }
    const param_type = fn_ty.fnParamType(param_index);
    const name = try scope.arena().dupeZ(u8, inst.positionals.name);
    return mod.addArg(b, inst.base.src, param_type, name);
}

fn zirLoop(mod: *Module, scope: *Scope, inst: *zir.Inst.Loop) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const parent_block = scope.cast(Scope.Block).?;

    // Reserve space for a Loop instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const loop_inst = try parent_block.arena.create(Inst.Loop);
    loop_inst.* = .{
        .base = .{
            .tag = Inst.Loop.base_tag,
            .ty = Type.initTag(.noreturn),
            .src = inst.base.src,
        },
        .body = undefined,
    };

    var child_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    defer child_block.instructions.deinit(mod.gpa);

    try analyzeBody(mod, &child_block, inst.positionals.body);

    // Loop repetition is implied so the last instruction may or may not be a noreturn instruction.

    try parent_block.instructions.append(mod.gpa, &loop_inst.base);
    loop_inst.body = .{ .instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items) };
    return &loop_inst.base;
}

fn zirBlockFlat(mod: *Module, scope: *Scope, inst: *zir.Inst.Block, is_comptime: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const parent_block = scope.cast(Scope.Block).?;

    var child_block = parent_block.makeSubBlock();
    defer child_block.instructions.deinit(mod.gpa);
    child_block.is_comptime = child_block.is_comptime or is_comptime;

    try analyzeBody(mod, &child_block, inst.positionals.body);

    // Move the analyzed instructions into the parent block arena.
    const copied_instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items);
    try parent_block.instructions.appendSlice(mod.gpa, copied_instructions);

    // The result of a flat block is the last instruction.
    const zir_inst_list = inst.positionals.body.instructions;
    const last_zir_inst = zir_inst_list[zir_inst_list.len - 1];
    return resolveInst(mod, scope, last_zir_inst);
}

fn zirBlock(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.Block,
    is_comptime: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const parent_block = scope.cast(Scope.Block).?;

    // Reserve space for a Block instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const block_inst = try parent_block.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = undefined, // Set after analysis.
            .src = inst.base.src,
        },
        .body = undefined,
    };

    var child_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
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
        .is_comptime = is_comptime or parent_block.is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    const merges = &child_block.label.?.merges;

    defer child_block.instructions.deinit(mod.gpa);
    defer merges.results.deinit(mod.gpa);
    defer merges.br_list.deinit(mod.gpa);

    try analyzeBody(mod, &child_block, inst.positionals.body);

    return analyzeBlockBody(mod, scope, &child_block, merges);
}

fn analyzeBlockBody(
    mod: *Module,
    scope: *Scope,
    child_block: *Scope.Block,
    merges: *Scope.Block.Merges,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const parent_block = scope.cast(Scope.Block).?;

    // Blocks must terminate with noreturn instruction.
    assert(child_block.instructions.items.len != 0);
    assert(child_block.instructions.items[child_block.instructions.items.len - 1].ty.isNoReturn());

    if (merges.results.items.len == 0) {
        // No need for a block instruction. We can put the new instructions
        // directly into the parent block.
        const copied_instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items);
        try parent_block.instructions.appendSlice(mod.gpa, copied_instructions);
        return copied_instructions[copied_instructions.len - 1];
    }
    if (merges.results.items.len == 1) {
        const last_inst_index = child_block.instructions.items.len - 1;
        const last_inst = child_block.instructions.items[last_inst_index];
        if (last_inst.breakBlock()) |br_block| {
            if (br_block == merges.block_inst) {
                // No need for a block instruction. We can put the new instructions directly
                // into the parent block. Here we omit the break instruction.
                const copied_instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items[0..last_inst_index]);
                try parent_block.instructions.appendSlice(mod.gpa, copied_instructions);
                return merges.results.items[0];
            }
        }
    }
    // It is impossible to have the number of results be > 1 in a comptime scope.
    assert(!child_block.is_comptime); // Should already got a compile error in the condbr condition.

    // Need to set the type and emit the Block instruction. This allows machine code generation
    // to emit a jump instruction to after the block when it encounters the break.
    try parent_block.instructions.append(mod.gpa, &merges.block_inst.base);
    const resolved_ty = try mod.resolvePeerTypes(scope, merges.results.items);
    merges.block_inst.base.ty = resolved_ty;
    merges.block_inst.body = .{
        .instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items),
    };
    // Now that the block has its type resolved, we need to go back into all the break
    // instructions, and insert type coercion on the operands.
    for (merges.br_list.items) |br| {
        if (br.operand.ty.eql(resolved_ty)) {
            // No type coercion needed.
            continue;
        }
        var coerce_block = parent_block.makeSubBlock();
        defer coerce_block.instructions.deinit(mod.gpa);
        const coerced_operand = try mod.coerce(&coerce_block.base, resolved_ty, br.operand);
        // If no instructions were produced, such as in the case of a coercion of a
        // constant value to a new type, we can simply point the br operand to it.
        if (coerce_block.instructions.items.len == 0) {
            br.operand = coerced_operand;
            continue;
        }
        assert(coerce_block.instructions.items[coerce_block.instructions.items.len - 1] == coerced_operand);
        // Here we depend on the br instruction having been over-allocated (if necessary)
        // inide analyzeBreak so that it can be converted into a br_block_flat instruction.
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
                .instructions = try parent_block.arena.dupe(*Inst, coerce_block.instructions.items),
            },
        };
    }
    return &merges.block_inst.base;
}

fn zirBreakpoint(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, Type.initTag(.void), .breakpoint);
}

fn zirBreak(mod: *Module, scope: *Scope, inst: *zir.Inst.Break) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    const block = inst.positionals.block;
    return analyzeBreak(mod, scope, inst.base.src, block, operand);
}

fn zirBreakVoid(mod: *Module, scope: *Scope, inst: *zir.Inst.BreakVoid) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const block = inst.positionals.block;
    const void_inst = try mod.constVoid(scope, inst.base.src);
    return analyzeBreak(mod, scope, inst.base.src, block, void_inst);
}

fn analyzeBreak(
    mod: *Module,
    scope: *Scope,
    src: usize,
    zir_block: *zir.Inst.Block,
    operand: *Inst,
) InnerError!*Inst {
    var opt_block = scope.cast(Scope.Block);
    while (opt_block) |block| {
        if (block.label) |*label| {
            if (label.zir_block == zir_block) {
                const b = try mod.requireFunctionBlock(scope, src);
                // Here we add a br instruction, but we over-allocate a little bit
                // (if necessary) to make it possible to convert the instruction into
                // a br_block_flat instruction later.
                const br = @ptrCast(*Inst.Br, try b.arena.alignedAlloc(
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
                try b.instructions.append(mod.gpa, &br.base);
                try label.merges.results.append(mod.gpa, operand);
                try label.merges.br_list.append(mod.gpa, br);
                return &br.base;
            }
        }
        opt_block = block.parent;
    } else unreachable;
}

fn zirDbgStmt(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    if (scope.cast(Scope.Block)) |b| {
        if (!b.is_comptime) {
            return mod.addNoOp(b, inst.base.src, Type.initTag(.void), .dbg_stmt);
        }
    }
    return mod.constVoid(scope, inst.base.src);
}

fn zirDeclRefStr(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclRefStr) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const decl_name = try resolveConstString(mod, scope, inst.positionals.name);
    return mod.analyzeDeclRefByName(scope, inst.base.src, decl_name);
}

fn zirDeclRef(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclRef) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.analyzeDeclRef(scope, inst.base.src, inst.positionals.decl);
}

fn zirDeclVal(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.analyzeDeclVal(scope, inst.base.src, inst.positionals.decl);
}

fn zirCall(mod: *Module, scope: *Scope, inst: *zir.Inst.Call) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const func = try resolveInst(mod, scope, inst.positionals.func);
    if (func.ty.zigTypeTag() != .Fn)
        return mod.fail(scope, inst.positionals.func.src, "type '{}' not a function", .{func.ty});

    const cc = func.ty.fnCallingConvention();
    if (cc == .Naked) {
        // TODO add error note: declared here
        return mod.fail(
            scope,
            inst.positionals.func.src,
            "unable to call function with naked calling convention",
            .{},
        );
    }
    const call_params_len = inst.positionals.args.len;
    const fn_params_len = func.ty.fnParamLen();
    if (func.ty.fnIsVarArgs()) {
        if (call_params_len < fn_params_len) {
            // TODO add error note: declared here
            return mod.fail(
                scope,
                inst.positionals.func.src,
                "expected at least {d} argument(s), found {d}",
                .{ fn_params_len, call_params_len },
            );
        }
        return mod.fail(scope, inst.base.src, "TODO implement support for calling var args functions", .{});
    } else if (fn_params_len != call_params_len) {
        // TODO add error note: declared here
        return mod.fail(
            scope,
            inst.positionals.func.src,
            "expected {d} argument(s), found {d}",
            .{ fn_params_len, call_params_len },
        );
    }

    if (inst.kw_args.modifier == .compile_time) {
        return mod.fail(scope, inst.base.src, "TODO implement comptime function calls", .{});
    }
    if (inst.kw_args.modifier != .auto) {
        return mod.fail(scope, inst.base.src, "TODO implement call with modifier {}", .{inst.kw_args.modifier});
    }

    // TODO handle function calls of generic functions

    const fn_param_types = try mod.gpa.alloc(Type, fn_params_len);
    defer mod.gpa.free(fn_param_types);
    func.ty.fnParamTypes(fn_param_types);

    const casted_args = try scope.arena().alloc(*Inst, fn_params_len);
    for (inst.positionals.args) |src_arg, i| {
        const uncasted_arg = try resolveInst(mod, scope, src_arg);
        casted_args[i] = try mod.coerce(scope, fn_param_types[i], uncasted_arg);
    }

    const ret_type = func.ty.fnReturnType();

    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const is_comptime_call = b.is_comptime or inst.kw_args.modifier == .compile_time;
    const is_inline_call = is_comptime_call or inst.kw_args.modifier == .always_inline or
        func.ty.fnCallingConvention() == .Inline;
    if (is_inline_call) {
        const func_val = try mod.resolveConstValue(scope, func);
        const module_fn = switch (func_val.tag()) {
            .function => func_val.castTag(.function).?.data,
            .extern_fn => return mod.fail(scope, inst.base.src, "{s} call of extern function", .{
                @as([]const u8, if (is_comptime_call) "comptime" else "inline"),
            }),
            else => unreachable,
        };

        // Analyze the ZIR. The same ZIR gets analyzed into a runtime function
        // or an inlined call depending on what union tag the `label` field is
        // set to in the `Scope.Block`.
        // This block instruction will be used to capture the return value from the
        // inlined function.
        const block_inst = try scope.arena().create(Inst.Block);
        block_inst.* = .{
            .base = .{
                .tag = Inst.Block.base_tag,
                .ty = ret_type,
                .src = inst.base.src,
            },
            .body = undefined,
        };
        // If this is the top of the inline/comptime call stack, we use this data.
        // Otherwise we pass on the shared data from the parent scope.
        var shared_inlining = Scope.Block.Inlining.Shared{
            .branch_count = 0,
            .caller = b.func,
        };
        // This one is shared among sub-blocks within the same callee, but not
        // shared among the entire inline/comptime call stack.
        var inlining = Scope.Block.Inlining{
            .shared = if (b.inlining) |inlining| inlining.shared else &shared_inlining,
            .param_index = 0,
            .casted_args = casted_args,
            .merges = .{
                .results = .{},
                .br_list = .{},
                .block_inst = block_inst,
            },
        };
        var inst_table = Scope.Block.InstTable.init(mod.gpa);
        defer inst_table.deinit();

        var child_block: Scope.Block = .{
            .parent = null,
            .inst_table = &inst_table,
            .func = module_fn,
            .owner_decl = scope.ownerDecl().?,
            .src_decl = module_fn.owner_decl,
            .instructions = .{},
            .arena = scope.arena(),
            .label = null,
            .inlining = &inlining,
            .is_comptime = is_comptime_call,
            .branch_quota = b.branch_quota,
        };

        const merges = &child_block.inlining.?.merges;

        defer child_block.instructions.deinit(mod.gpa);
        defer merges.results.deinit(mod.gpa);
        defer merges.br_list.deinit(mod.gpa);

        try mod.emitBackwardBranch(&child_block, inst.base.src);

        // This will have return instructions analyzed as break instructions to
        // the block_inst above.
        try analyzeBody(mod, &child_block, module_fn.zir);

        return analyzeBlockBody(mod, scope, &child_block, merges);
    }

    return mod.addCall(b, inst.base.src, ret_type, func, casted_args);
}

fn zirFn(mod: *Module, scope: *Scope, fn_inst: *zir.Inst.Fn) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const fn_type = try resolveType(mod, scope, fn_inst.positionals.fn_type);
    const new_func = try scope.arena().create(Module.Fn);
    new_func.* = .{
        .state = if (fn_type.fnCallingConvention() == .Inline) .inline_only else .queued,
        .zir = fn_inst.positionals.body,
        .body = undefined,
        .owner_decl = scope.ownerDecl().?,
    };
    return mod.constInst(scope, fn_inst.base.src, .{
        .ty = fn_type,
        .val = try Value.Tag.function.create(scope.arena(), new_func),
    });
}

fn zirIntType(mod: *Module, scope: *Scope, inttype: *zir.Inst.IntType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inttype.base.src, "TODO implement inttype", .{});
}

fn zirOptionalType(mod: *Module, scope: *Scope, optional: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const child_type = try resolveType(mod, scope, optional.positionals.operand);

    return mod.constType(scope, optional.base.src, try mod.optionalType(scope, child_type));
}

fn zirArrayType(mod: *Module, scope: *Scope, array: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO these should be lazily evaluated
    const len = try resolveInstConst(mod, scope, array.positionals.lhs);
    const elem_type = try resolveType(mod, scope, array.positionals.rhs);

    return mod.constType(scope, array.base.src, try mod.arrayType(scope, len.val.toUnsignedInt(), null, elem_type));
}

fn zirArrayTypeSentinel(mod: *Module, scope: *Scope, array: *zir.Inst.ArrayTypeSentinel) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO these should be lazily evaluated
    const len = try resolveInstConst(mod, scope, array.positionals.len);
    const sentinel = try resolveInstConst(mod, scope, array.positionals.sentinel);
    const elem_type = try resolveType(mod, scope, array.positionals.elem_type);

    return mod.constType(scope, array.base.src, try mod.arrayType(scope, len.val.toUnsignedInt(), sentinel.val, elem_type));
}

fn zirErrorUnionType(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const error_union = try resolveType(mod, scope, inst.positionals.lhs);
    const payload = try resolveType(mod, scope, inst.positionals.rhs);

    if (error_union.zigTypeTag() != .ErrorSet) {
        return mod.fail(scope, inst.base.src, "expected error set type, found {}", .{error_union.elemType()});
    }

    return mod.constType(scope, inst.base.src, try mod.errorUnionType(scope, error_union, payload));
}

fn zirAnyframeType(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const return_type = try resolveType(mod, scope, inst.positionals.operand);

    return mod.constType(scope, inst.base.src, try mod.anyframeType(scope, return_type));
}

fn zirErrorSet(mod: *Module, scope: *Scope, inst: *zir.Inst.ErrorSet) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // The declarations arena will store the hashmap.
    var new_decl_arena = std.heap.ArenaAllocator.init(mod.gpa);
    errdefer new_decl_arena.deinit();

    const payload = try new_decl_arena.allocator.create(Value.Payload.ErrorSet);
    payload.* = .{
        .base = .{ .tag = .error_set },
        .data = .{
            .fields = .{},
            .decl = undefined, // populated below
        },
    };
    try payload.data.fields.ensureCapacity(&new_decl_arena.allocator, @intCast(u32, inst.positionals.fields.len));

    for (inst.positionals.fields) |field_name| {
        const entry = try mod.getErrorValue(field_name);
        if (payload.data.fields.fetchPutAssumeCapacity(entry.key, entry.value)) |prev| {
            return mod.fail(scope, inst.base.src, "duplicate error: '{s}'", .{field_name});
        }
    }
    // TODO create name in format "error:line:column"
    const new_decl = try mod.createAnonymousDecl(scope, &new_decl_arena, .{
        .ty = Type.initTag(.type),
        .val = Value.initPayload(&payload.base),
    });
    payload.data.decl = new_decl;
    return mod.analyzeDeclVal(scope, inst.base.src, new_decl);
}

fn zirMergeErrorSets(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement merge_error_sets", .{});
}

fn zirEnumLiteral(mod: *Module, scope: *Scope, inst: *zir.Inst.EnumLiteral) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const duped_name = try scope.arena().dupe(u8, inst.positionals.name);
    return mod.constInst(scope, inst.base.src, .{
        .ty = Type.initTag(.enum_literal),
        .val = try Value.Tag.enum_literal.create(scope.arena(), duped_name),
    });
}

/// Pointer in, pointer out.
fn zirOptionalPayloadPtr(
    mod: *Module,
    scope: *Scope,
    unwrap: *zir.Inst.UnOp,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const optional_ptr = try resolveInst(mod, scope, unwrap.positionals.operand);
    assert(optional_ptr.ty.zigTypeTag() == .Pointer);

    const opt_type = optional_ptr.ty.elemType();
    if (opt_type.zigTypeTag() != .Optional) {
        return mod.fail(scope, unwrap.base.src, "expected optional type, found {}", .{opt_type});
    }

    const child_type = try opt_type.optionalChildAlloc(scope.arena());
    const child_pointer = try mod.simplePtrType(scope, unwrap.base.src, child_type, !optional_ptr.ty.isConstPtr(), .One);

    if (optional_ptr.value()) |pointer_val| {
        const val = try pointer_val.pointerDeref(scope.arena());
        if (val.isNull()) {
            return mod.fail(scope, unwrap.base.src, "unable to unwrap null", .{});
        }
        // The same Value represents the pointer to the optional and the payload.
        return mod.constInst(scope, unwrap.base.src, .{
            .ty = child_pointer,
            .val = pointer_val,
        });
    }

    const b = try mod.requireRuntimeBlock(scope, unwrap.base.src);
    if (safety_check and mod.wantSafety(scope)) {
        const is_non_null = try mod.addUnOp(b, unwrap.base.src, Type.initTag(.bool), .is_non_null_ptr, optional_ptr);
        try mod.addSafetyCheck(b, is_non_null, .unwrap_null);
    }
    return mod.addUnOp(b, unwrap.base.src, child_pointer, .optional_payload_ptr, optional_ptr);
}

/// Value in, value out.
fn zirOptionalPayload(
    mod: *Module,
    scope: *Scope,
    unwrap: *zir.Inst.UnOp,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const operand = try resolveInst(mod, scope, unwrap.positionals.operand);
    const opt_type = operand.ty;
    if (opt_type.zigTypeTag() != .Optional) {
        return mod.fail(scope, unwrap.base.src, "expected optional type, found {}", .{opt_type});
    }

    const child_type = try opt_type.optionalChildAlloc(scope.arena());

    if (operand.value()) |val| {
        if (val.isNull()) {
            return mod.fail(scope, unwrap.base.src, "unable to unwrap null", .{});
        }
        return mod.constInst(scope, unwrap.base.src, .{
            .ty = child_type,
            .val = val,
        });
    }

    const b = try mod.requireRuntimeBlock(scope, unwrap.base.src);
    if (safety_check and mod.wantSafety(scope)) {
        const is_non_null = try mod.addUnOp(b, unwrap.base.src, Type.initTag(.bool), .is_non_null, operand);
        try mod.addSafetyCheck(b, is_non_null, .unwrap_null);
    }
    return mod.addUnOp(b, unwrap.base.src, child_type, .optional_payload, operand);
}

/// Value in, value out
fn zirErrUnionPayload(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp, safety_check: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.zirErrUnionPayload", .{});
}

/// Pointer in, pointer out
fn zirErrUnionPayloadPtr(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp, safety_check: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.zirErrUnionPayloadPtr", .{});
}

/// Value in, value out
fn zirErrUnionCode(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.zirErrUnionCode", .{});
}

/// Pointer in, value out
fn zirErrUnionCodePtr(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.zirErrUnionCodePtr", .{});
}

fn zirEnsureErrPayloadVoid(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zirEnsureErrPayloadVoid", .{});
}

fn zirFnType(mod: *Module, scope: *Scope, fntype: *zir.Inst.FnType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const return_type = try resolveType(mod, scope, fntype.positionals.return_type);
    const cc_tv = try resolveInstConst(mod, scope, fntype.positionals.cc);
    const cc_str = cc_tv.val.castTag(.enum_literal).?.data;
    const cc = std.meta.stringToEnum(std.builtin.CallingConvention, cc_str) orelse
        return mod.fail(scope, fntype.positionals.cc.src, "Unknown calling convention {s}", .{cc_str});

    // Hot path for some common function types.
    if (fntype.positionals.param_types.len == 0) {
        if (return_type.zigTypeTag() == .NoReturn and cc == .Unspecified) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and cc == .Unspecified) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_void_no_args));
        }

        if (return_type.zigTypeTag() == .NoReturn and cc == .Naked) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and cc == .C) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_ccc_void_no_args));
        }
    }

    const arena = scope.arena();
    const param_types = try arena.alloc(Type, fntype.positionals.param_types.len);
    for (fntype.positionals.param_types) |param_type, i| {
        const resolved = try resolveType(mod, scope, param_type);
        // TODO skip for comptime params
        if (!resolved.isValidVarType(false)) {
            return mod.fail(scope, param_type.src, "parameter of type '{}' must be declared comptime", .{resolved});
        }
        param_types[i] = resolved;
    }

    const fn_ty = try Type.Tag.function.create(arena, .{
        .param_types = param_types,
        .return_type = return_type,
        .cc = cc,
    });
    return mod.constType(scope, fntype.base.src, fn_ty);
}

fn zirPrimitive(mod: *Module, scope: *Scope, primitive: *zir.Inst.Primitive) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.constInst(scope, primitive.base.src, primitive.positionals.tag.toTypedValue());
}

fn zirAs(mod: *Module, scope: *Scope, as: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, as.positionals.lhs);
    const new_inst = try resolveInst(mod, scope, as.positionals.rhs);
    return mod.coerce(scope, dest_type, new_inst);
}

fn zirPtrtoint(mod: *Module, scope: *Scope, ptrtoint: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, ptrtoint.positionals.operand);
    if (ptr.ty.zigTypeTag() != .Pointer) {
        return mod.fail(scope, ptrtoint.positionals.operand.src, "expected pointer, found '{}'", .{ptr.ty});
    }
    // TODO handle known-pointer-address
    const b = try mod.requireRuntimeBlock(scope, ptrtoint.base.src);
    const ty = Type.initTag(.usize);
    return mod.addUnOp(b, ptrtoint.base.src, ty, .ptrtoint, ptr);
}

fn zirFieldVal(mod: *Module, scope: *Scope, inst: *zir.Inst.Field) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = inst.positionals.field_name;
    const object_ptr = try mod.analyzeRef(scope, inst.base.src, object);
    const result_ptr = try mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, inst.base.src);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn zirFieldPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.Field) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object_ptr = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = inst.positionals.field_name;
    return mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, inst.base.src);
}

fn zirFieldValNamed(mod: *Module, scope: *Scope, inst: *zir.Inst.FieldNamed) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = try resolveConstString(mod, scope, inst.positionals.field_name);
    const fsrc = inst.positionals.field_name.src;
    const object_ptr = try mod.analyzeRef(scope, inst.base.src, object);
    const result_ptr = try mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, fsrc);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn zirFieldPtrNamed(mod: *Module, scope: *Scope, inst: *zir.Inst.FieldNamed) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object_ptr = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = try resolveConstString(mod, scope, inst.positionals.field_name);
    const fsrc = inst.positionals.field_name.src;
    return mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, fsrc);
}

fn zirIntcast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, inst.positionals.lhs);
    const operand = try resolveInst(mod, scope, inst.positionals.rhs);

    const dest_is_comptime_int = switch (dest_type.zigTypeTag()) {
        .ComptimeInt => true,
        .Int => false,
        else => return mod.fail(
            scope,
            inst.positionals.lhs.src,
            "expected integer type, found '{}'",
            .{
                dest_type,
            },
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeInt, .Int => {},
        else => return mod.fail(
            scope,
            inst.positionals.rhs.src,
            "expected integer type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return mod.coerce(scope, dest_type, operand);
    } else if (dest_is_comptime_int) {
        return mod.fail(scope, inst.base.src, "unable to cast runtime value to 'comptime_int'", .{});
    }

    return mod.fail(scope, inst.base.src, "TODO implement analyze widen or shorten int", .{});
}

fn zirBitcast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, inst.positionals.lhs);
    const operand = try resolveInst(mod, scope, inst.positionals.rhs);
    return mod.bitcast(scope, dest_type, operand);
}

fn zirFloatcast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, inst.positionals.lhs);
    const operand = try resolveInst(mod, scope, inst.positionals.rhs);

    const dest_is_comptime_float = switch (dest_type.zigTypeTag()) {
        .ComptimeFloat => true,
        .Float => false,
        else => return mod.fail(
            scope,
            inst.positionals.lhs.src,
            "expected float type, found '{}'",
            .{
                dest_type,
            },
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeFloat, .Float, .ComptimeInt => {},
        else => return mod.fail(
            scope,
            inst.positionals.rhs.src,
            "expected float type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return mod.coerce(scope, dest_type, operand);
    } else if (dest_is_comptime_float) {
        return mod.fail(scope, inst.base.src, "unable to cast runtime value to 'comptime_float'", .{});
    }

    return mod.fail(scope, inst.base.src, "TODO implement analyze widen or shorten float", .{});
}

fn zirElemVal(mod: *Module, scope: *Scope, inst: *zir.Inst.Elem) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const array = try resolveInst(mod, scope, inst.positionals.array);
    const array_ptr = try mod.analyzeRef(scope, inst.base.src, array);
    const elem_index = try resolveInst(mod, scope, inst.positionals.index);
    const result_ptr = try mod.elemPtr(scope, inst.base.src, array_ptr, elem_index);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn zirElemPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.Elem) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const array_ptr = try resolveInst(mod, scope, inst.positionals.array);
    const elem_index = try resolveInst(mod, scope, inst.positionals.index);
    return mod.elemPtr(scope, inst.base.src, array_ptr, elem_index);
}

fn zirSlice(mod: *Module, scope: *Scope, inst: *zir.Inst.Slice) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const array_ptr = try resolveInst(mod, scope, inst.positionals.array_ptr);
    const start = try resolveInst(mod, scope, inst.positionals.start);
    const end = if (inst.kw_args.end) |end| try resolveInst(mod, scope, end) else null;
    const sentinel = if (inst.kw_args.sentinel) |sentinel| try resolveInst(mod, scope, sentinel) else null;

    return mod.analyzeSlice(scope, inst.base.src, array_ptr, start, end, sentinel);
}

fn zirSliceStart(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const array_ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const start = try resolveInst(mod, scope, inst.positionals.rhs);

    return mod.analyzeSlice(scope, inst.base.src, array_ptr, start, null, null);
}

fn zirSwitchRange(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const start = try resolveInst(mod, scope, inst.positionals.lhs);
    const end = try resolveInst(mod, scope, inst.positionals.rhs);

    switch (start.ty.zigTypeTag()) {
        .Int, .ComptimeInt => {},
        else => return mod.constVoid(scope, inst.base.src),
    }
    switch (end.ty.zigTypeTag()) {
        .Int, .ComptimeInt => {},
        else => return mod.constVoid(scope, inst.base.src),
    }
    // .switch_range must be inside a comptime scope
    const start_val = start.value().?;
    const end_val = end.value().?;
    if (start_val.compare(.gte, end_val)) {
        return mod.fail(scope, inst.base.src, "range start value must be smaller than the end value", .{});
    }
    return mod.constVoid(scope, inst.base.src);
}

fn zirSwitchBr(mod: *Module, scope: *Scope, inst: *zir.Inst.SwitchBr) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const target = try resolveInst(mod, scope, inst.positionals.target);
    try validateSwitch(mod, scope, target, inst);

    if (try mod.resolveDefinedValue(scope, target)) |target_val| {
        for (inst.positionals.cases) |case| {
            const resolved = try resolveInst(mod, scope, case.item);
            const casted = try mod.coerce(scope, target.ty, resolved);
            const item = try mod.resolveConstValue(scope, casted);

            if (target_val.eql(item)) {
                try analyzeBody(mod, scope.cast(Scope.Block).?, case.body);
                return mod.constNoReturn(scope, inst.base.src);
            }
        }
        try analyzeBody(mod, scope.cast(Scope.Block).?, inst.positionals.else_body);
        return mod.constNoReturn(scope, inst.base.src);
    }

    if (inst.positionals.cases.len == 0) {
        // no cases just analyze else_branch
        try analyzeBody(mod, scope.cast(Scope.Block).?, inst.positionals.else_body);
        return mod.constNoReturn(scope, inst.base.src);
    }

    const parent_block = try mod.requireRuntimeBlock(scope, inst.base.src);
    const cases = try parent_block.arena.alloc(Inst.SwitchBr.Case, inst.positionals.cases.len);

    var case_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    defer case_block.instructions.deinit(mod.gpa);

    for (inst.positionals.cases) |case, i| {
        // Reset without freeing.
        case_block.instructions.items.len = 0;

        const resolved = try resolveInst(mod, scope, case.item);
        const casted = try mod.coerce(scope, target.ty, resolved);
        const item = try mod.resolveConstValue(scope, casted);

        try analyzeBody(mod, &case_block, case.body);

        cases[i] = .{
            .item = item,
            .body = .{ .instructions = try parent_block.arena.dupe(*Inst, case_block.instructions.items) },
        };
    }

    case_block.instructions.items.len = 0;
    try analyzeBody(mod, &case_block, inst.positionals.else_body);

    const else_body: ir.Body = .{
        .instructions = try parent_block.arena.dupe(*Inst, case_block.instructions.items),
    };

    return mod.addSwitchBr(parent_block, inst.base.src, target, cases, else_body);
}

fn validateSwitch(mod: *Module, scope: *Scope, target: *Inst, inst: *zir.Inst.SwitchBr) InnerError!void {
    // validate usage of '_' prongs
    if (inst.kw_args.special_prong == .underscore and target.ty.zigTypeTag() != .Enum) {
        return mod.fail(scope, inst.base.src, "'_' prong only allowed when switching on non-exhaustive enums", .{});
        // TODO notes "'_' prong here" inst.positionals.cases[last].src
    }

    // check that target type supports ranges
    if (inst.kw_args.range) |range_inst| {
        switch (target.ty.zigTypeTag()) {
            .Int, .ComptimeInt => {},
            else => {
                return mod.fail(scope, target.src, "ranges not allowed when switching on type {}", .{target.ty});
                // TODO notes "range used here" range_inst.src
            },
        }
    }

    // validate for duplicate items/missing else prong
    switch (target.ty.zigTypeTag()) {
        .Enum => return mod.fail(scope, inst.base.src, "TODO validateSwitch .Enum", .{}),
        .ErrorSet => return mod.fail(scope, inst.base.src, "TODO validateSwitch .ErrorSet", .{}),
        .Union => return mod.fail(scope, inst.base.src, "TODO validateSwitch .Union", .{}),
        .Int, .ComptimeInt => {
            var range_set = @import("RangeSet.zig").init(mod.gpa);
            defer range_set.deinit();

            for (inst.positionals.items) |item| {
                const maybe_src = if (item.castTag(.switch_range)) |range| blk: {
                    const start_resolved = try resolveInst(mod, scope, range.positionals.lhs);
                    const start_casted = try mod.coerce(scope, target.ty, start_resolved);
                    const end_resolved = try resolveInst(mod, scope, range.positionals.rhs);
                    const end_casted = try mod.coerce(scope, target.ty, end_resolved);

                    break :blk try range_set.add(
                        try mod.resolveConstValue(scope, start_casted),
                        try mod.resolveConstValue(scope, end_casted),
                        item.src,
                    );
                } else blk: {
                    const resolved = try resolveInst(mod, scope, item);
                    const casted = try mod.coerce(scope, target.ty, resolved);
                    const value = try mod.resolveConstValue(scope, casted);
                    break :blk try range_set.add(value, value, item.src);
                };

                if (maybe_src) |previous_src| {
                    return mod.fail(scope, item.src, "duplicate switch value", .{});
                    // TODO notes "previous value is here" previous_src
                }
            }

            if (target.ty.zigTypeTag() == .Int) {
                var arena = std.heap.ArenaAllocator.init(mod.gpa);
                defer arena.deinit();

                const start = try target.ty.minInt(&arena, mod.getTarget());
                const end = try target.ty.maxInt(&arena, mod.getTarget());
                if (try range_set.spans(start, end)) {
                    if (inst.kw_args.special_prong == .@"else") {
                        return mod.fail(scope, inst.base.src, "unreachable else prong, all cases already handled", .{});
                    }
                    return;
                }
            }

            if (inst.kw_args.special_prong != .@"else") {
                return mod.fail(scope, inst.base.src, "switch must handle all possibilities", .{});
            }
        },
        .Bool => {
            var true_count: u8 = 0;
            var false_count: u8 = 0;
            for (inst.positionals.items) |item| {
                const resolved = try resolveInst(mod, scope, item);
                const casted = try mod.coerce(scope, Type.initTag(.bool), resolved);
                if ((try mod.resolveConstValue(scope, casted)).toBool()) {
                    true_count += 1;
                } else {
                    false_count += 1;
                }

                if (true_count + false_count > 2) {
                    return mod.fail(scope, item.src, "duplicate switch value", .{});
                }
            }
            if ((true_count + false_count < 2) and inst.kw_args.special_prong != .@"else") {
                return mod.fail(scope, inst.base.src, "switch must handle all possibilities", .{});
            }
            if ((true_count + false_count == 2) and inst.kw_args.special_prong == .@"else") {
                return mod.fail(scope, inst.base.src, "unreachable else prong, all cases already handled", .{});
            }
        },
        .EnumLiteral, .Void, .Fn, .Pointer, .Type => {
            if (inst.kw_args.special_prong != .@"else") {
                return mod.fail(scope, inst.base.src, "else prong required when switching on type '{}'", .{target.ty});
            }

            var seen_values = std.HashMap(Value, usize, Value.hash, Value.eql, std.hash_map.DefaultMaxLoadPercentage).init(mod.gpa);
            defer seen_values.deinit();

            for (inst.positionals.items) |item| {
                const resolved = try resolveInst(mod, scope, item);
                const casted = try mod.coerce(scope, target.ty, resolved);
                const val = try mod.resolveConstValue(scope, casted);

                if (try seen_values.fetchPut(val, item.src)) |prev| {
                    return mod.fail(scope, item.src, "duplicate switch value", .{});
                    // TODO notes "previous value here" prev.value
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
        => {
            return mod.fail(scope, target.src, "invalid switch target type '{}'", .{target.ty});
        },
    }
}

fn zirImport(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveConstString(mod, scope, inst.positionals.operand);

    const file_scope = mod.analyzeImport(scope, inst.base.src, operand) catch |err| switch (err) {
        error.ImportOutsidePkgPath => {
            return mod.fail(scope, inst.base.src, "import of file outside package path: '{s}'", .{operand});
        },
        error.FileNotFound => {
            return mod.fail(scope, inst.base.src, "unable to find '{s}'", .{operand});
        },
        else => {
            // TODO: make sure this gets retried and not cached
            return mod.fail(scope, inst.base.src, "unable to open '{s}': {s}", .{ operand, @errorName(err) });
        },
    };
    return mod.constType(scope, inst.base.src, file_scope.root_container.ty);
}

fn zirShl(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirShl", .{});
}

fn zirShr(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirShr", .{});
}

fn zirBitwise(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const lhs = try resolveInst(mod, scope, inst.positionals.lhs);
    const rhs = try resolveInst(mod, scope, inst.positionals.rhs);

    const instructions = &[_]*Inst{ lhs, rhs };
    const resolved_type = try mod.resolvePeerTypes(scope, instructions);
    const casted_lhs = try mod.coerce(scope, resolved_type, lhs);
    const casted_rhs = try mod.coerce(scope, resolved_type, rhs);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    if (lhs.ty.zigTypeTag() == .Vector and rhs.ty.zigTypeTag() == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return mod.fail(scope, inst.base.src, "vector length mismatch: {d} and {d}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return mod.fail(scope, inst.base.src, "TODO implement support for vectors in analyzeInstBitwise", .{});
    } else if (lhs.ty.zigTypeTag() == .Vector or rhs.ty.zigTypeTag() == .Vector) {
        return mod.fail(scope, inst.base.src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;

    if (!is_int) {
        return mod.fail(scope, inst.base.src, "invalid operands to binary bitwise expression: '{s}' and '{s}'", .{ @tagName(lhs.ty.zigTypeTag()), @tagName(rhs.ty.zigTypeTag()) });
    }

    if (casted_lhs.value()) |lhs_val| {
        if (casted_rhs.value()) |rhs_val| {
            if (lhs_val.isUndef() or rhs_val.isUndef()) {
                return mod.constInst(scope, inst.base.src, .{
                    .ty = resolved_type,
                    .val = Value.initTag(.undef),
                });
            }
            return mod.fail(scope, inst.base.src, "TODO implement comptime bitwise operations", .{});
        }
    }

    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    const ir_tag = switch (inst.base.tag) {
        .bit_and => Inst.Tag.bit_and,
        .bit_or => Inst.Tag.bit_or,
        .xor => Inst.Tag.xor,
        else => unreachable,
    };

    return mod.addBinOp(b, inst.base.src, scalar_type, ir_tag, casted_lhs, casted_rhs);
}

fn zirBitNot(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirBitNot", .{});
}

fn zirArrayCat(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirArrayCat", .{});
}

fn zirArrayMul(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zirArrayMul", .{});
}

fn zirArithmetic(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const lhs = try resolveInst(mod, scope, inst.positionals.lhs);
    const rhs = try resolveInst(mod, scope, inst.positionals.rhs);

    const instructions = &[_]*Inst{ lhs, rhs };
    const resolved_type = try mod.resolvePeerTypes(scope, instructions);
    const casted_lhs = try mod.coerce(scope, resolved_type, lhs);
    const casted_rhs = try mod.coerce(scope, resolved_type, rhs);

    const scalar_type = if (resolved_type.zigTypeTag() == .Vector)
        resolved_type.elemType()
    else
        resolved_type;

    const scalar_tag = scalar_type.zigTypeTag();

    if (lhs.ty.zigTypeTag() == .Vector and rhs.ty.zigTypeTag() == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return mod.fail(scope, inst.base.src, "vector length mismatch: {d} and {d}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return mod.fail(scope, inst.base.src, "TODO implement support for vectors in analyzeInstBinOp", .{});
    } else if (lhs.ty.zigTypeTag() == .Vector or rhs.ty.zigTypeTag() == .Vector) {
        return mod.fail(scope, inst.base.src, "mixed scalar and vector operands to binary expression: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    const is_int = scalar_tag == .Int or scalar_tag == .ComptimeInt;
    const is_float = scalar_tag == .Float or scalar_tag == .ComptimeFloat;

    if (!is_int and !(is_float and floatOpAllowed(inst.base.tag))) {
        return mod.fail(scope, inst.base.src, "invalid operands to binary expression: '{s}' and '{s}'", .{ @tagName(lhs.ty.zigTypeTag()), @tagName(rhs.ty.zigTypeTag()) });
    }

    if (casted_lhs.value()) |lhs_val| {
        if (casted_rhs.value()) |rhs_val| {
            if (lhs_val.isUndef() or rhs_val.isUndef()) {
                return mod.constInst(scope, inst.base.src, .{
                    .ty = resolved_type,
                    .val = Value.initTag(.undef),
                });
            }
            return analyzeInstComptimeOp(mod, scope, scalar_type, inst, lhs_val, rhs_val);
        }
    }

    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    const ir_tag = switch (inst.base.tag) {
        .add => Inst.Tag.add,
        .sub => Inst.Tag.sub,
        else => return mod.fail(scope, inst.base.src, "TODO implement arithmetic for operand '{s}''", .{@tagName(inst.base.tag)}),
    };

    return mod.addBinOp(b, inst.base.src, scalar_type, ir_tag, casted_lhs, casted_rhs);
}

/// Analyzes operands that are known at comptime
fn analyzeInstComptimeOp(mod: *Module, scope: *Scope, res_type: Type, inst: *zir.Inst.BinOp, lhs_val: Value, rhs_val: Value) InnerError!*Inst {
    // incase rhs is 0, simply return lhs without doing any calculations
    // TODO Once division is implemented we should throw an error when dividing by 0.
    if (rhs_val.compareWithZero(.eq)) {
        return mod.constInst(scope, inst.base.src, .{
            .ty = res_type,
            .val = lhs_val,
        });
    }
    const is_int = res_type.isInt() or res_type.zigTypeTag() == .ComptimeInt;

    const value = switch (inst.base.tag) {
        .add => blk: {
            const val = if (is_int)
                try Module.intAdd(scope.arena(), lhs_val, rhs_val)
            else
                try mod.floatAdd(scope, res_type, inst.base.src, lhs_val, rhs_val);
            break :blk val;
        },
        .sub => blk: {
            const val = if (is_int)
                try Module.intSub(scope.arena(), lhs_val, rhs_val)
            else
                try mod.floatSub(scope, res_type, inst.base.src, lhs_val, rhs_val);
            break :blk val;
        },
        else => return mod.fail(scope, inst.base.src, "TODO Implement arithmetic operand '{s}'", .{@tagName(inst.base.tag)}),
    };

    log.debug("{s}({}, {}) result: {}", .{ @tagName(inst.base.tag), lhs_val, rhs_val, value });

    return mod.constInst(scope, inst.base.src, .{
        .ty = res_type,
        .val = value,
    });
}

fn zirDeref(mod: *Module, scope: *Scope, deref: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, deref.positionals.operand);
    return mod.analyzeDeref(scope, deref.base.src, ptr, deref.positionals.operand.src);
}

fn zirAsm(mod: *Module, scope: *Scope, assembly: *zir.Inst.Asm) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const return_type = try resolveType(mod, scope, assembly.positionals.return_type);
    const asm_source = try resolveConstString(mod, scope, assembly.positionals.asm_source);
    const output = if (assembly.kw_args.output) |o| try resolveConstString(mod, scope, o) else null;

    const inputs = try scope.arena().alloc([]const u8, assembly.kw_args.inputs.len);
    const clobbers = try scope.arena().alloc([]const u8, assembly.kw_args.clobbers.len);
    const args = try scope.arena().alloc(*Inst, assembly.kw_args.args.len);

    for (inputs) |*elem, i| {
        elem.* = try resolveConstString(mod, scope, assembly.kw_args.inputs[i]);
    }
    for (clobbers) |*elem, i| {
        elem.* = try resolveConstString(mod, scope, assembly.kw_args.clobbers[i]);
    }
    for (args) |*elem, i| {
        const arg = try resolveInst(mod, scope, assembly.kw_args.args[i]);
        elem.* = try mod.coerce(scope, Type.initTag(.usize), arg);
    }

    const b = try mod.requireRuntimeBlock(scope, assembly.base.src);
    const inst = try b.arena.create(Inst.Assembly);
    inst.* = .{
        .base = .{
            .tag = .assembly,
            .ty = return_type,
            .src = assembly.base.src,
        },
        .asm_source = asm_source,
        .is_volatile = assembly.kw_args.@"volatile",
        .output = output,
        .inputs = inputs,
        .clobbers = clobbers,
        .args = args,
    };
    try b.instructions.append(mod.gpa, &inst.base);
    return &inst.base;
}

fn zirCmp(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.BinOp,
    op: std.math.CompareOperator,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const lhs = try resolveInst(mod, scope, inst.positionals.lhs);
    const rhs = try resolveInst(mod, scope, inst.positionals.rhs);

    const is_equality_cmp = switch (op) {
        .eq, .neq => true,
        else => false,
    };
    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();
    if (is_equality_cmp and lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
        // null == null, null != null
        return mod.constBool(scope, inst.base.src, op == .eq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
        rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
    {
        // comparing null with optionals
        const opt_operand = if (lhs_ty_tag == .Optional) lhs else rhs;
        return mod.analyzeIsNull(scope, inst.base.src, opt_operand, op == .neq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs.ty.isCPtr()) or (rhs_ty_tag == .Null and lhs.ty.isCPtr())))
    {
        return mod.fail(scope, inst.base.src, "TODO implement C pointer cmp", .{});
    } else if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
        const non_null_type = if (lhs_ty_tag == .Null) rhs.ty else lhs.ty;
        return mod.fail(scope, inst.base.src, "comparison of '{}' with null", .{non_null_type});
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) or
        (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union)))
    {
        return mod.fail(scope, inst.base.src, "TODO implement equality comparison between a union's tag value and an enum literal", .{});
    } else if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
        if (!is_equality_cmp) {
            return mod.fail(scope, inst.base.src, "{s} operator not allowed for errors", .{@tagName(op)});
        }
        return mod.fail(scope, inst.base.src, "TODO implement equality comparison between errors", .{});
    } else if (lhs.ty.isNumeric() and rhs.ty.isNumeric()) {
        // This operation allows any combination of integer and float types, regardless of the
        // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
        // numeric types.
        return mod.cmpNumeric(scope, inst.base.src, lhs, rhs, op);
    } else if (lhs_ty_tag == .Type and rhs_ty_tag == .Type) {
        if (!is_equality_cmp) {
            return mod.fail(scope, inst.base.src, "{s} operator not allowed for types", .{@tagName(op)});
        }
        return mod.constBool(scope, inst.base.src, lhs.value().?.eql(rhs.value().?) == (op == .eq));
    }
    return mod.fail(scope, inst.base.src, "TODO implement more cmp analysis", .{});
}

fn zirTypeof(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.constType(scope, inst.base.src, operand.ty);
}

fn zirTypeofPeer(mod: *Module, scope: *Scope, inst: *zir.Inst.TypeOfPeer) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    var insts_to_res = try mod.gpa.alloc(*ir.Inst, inst.positionals.items.len);
    defer mod.gpa.free(insts_to_res);
    for (inst.positionals.items) |item, i| {
        insts_to_res[i] = try resolveInst(mod, scope, item);
    }
    const pt_res = try mod.resolvePeerTypes(scope, insts_to_res);
    return mod.constType(scope, inst.base.src, pt_res);
}

fn zirBoolNot(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const uncasted_operand = try resolveInst(mod, scope, inst.positionals.operand);
    const bool_type = Type.initTag(.bool);
    const operand = try mod.coerce(scope, bool_type, uncasted_operand);
    if (try mod.resolveDefinedValue(scope, operand)) |val| {
        return mod.constBool(scope, inst.base.src, !val.toBool());
    }
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addUnOp(b, inst.base.src, bool_type, .not, operand);
}

fn zirBoolOp(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const bool_type = Type.initTag(.bool);
    const uncasted_lhs = try resolveInst(mod, scope, inst.positionals.lhs);
    const lhs = try mod.coerce(scope, bool_type, uncasted_lhs);
    const uncasted_rhs = try resolveInst(mod, scope, inst.positionals.rhs);
    const rhs = try mod.coerce(scope, bool_type, uncasted_rhs);

    const is_bool_or = inst.base.tag == .bool_or;

    if (lhs.value()) |lhs_val| {
        if (rhs.value()) |rhs_val| {
            if (is_bool_or) {
                return mod.constBool(scope, inst.base.src, lhs_val.toBool() or rhs_val.toBool());
            } else {
                return mod.constBool(scope, inst.base.src, lhs_val.toBool() and rhs_val.toBool());
            }
        }
    }
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addBinOp(b, inst.base.src, bool_type, if (is_bool_or) .bool_or else .bool_and, lhs, rhs);
}

fn zirIsNull(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, invert_logic: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeIsNull(scope, inst.base.src, operand, invert_logic);
}

fn zirIsNullPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, invert_logic: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const loaded = try mod.analyzeDeref(scope, inst.base.src, ptr, ptr.src);
    return mod.analyzeIsNull(scope, inst.base.src, loaded, invert_logic);
}

fn zirIsErr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeIsErr(scope, inst.base.src, operand);
}

fn zirIsErrPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const loaded = try mod.analyzeDeref(scope, inst.base.src, ptr, ptr.src);
    return mod.analyzeIsErr(scope, inst.base.src, loaded);
}

fn zirCondbr(mod: *Module, scope: *Scope, inst: *zir.Inst.CondBr) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const uncasted_cond = try resolveInst(mod, scope, inst.positionals.condition);
    const cond = try mod.coerce(scope, Type.initTag(.bool), uncasted_cond);

    const parent_block = scope.cast(Scope.Block).?;

    if (try mod.resolveDefinedValue(scope, cond)) |cond_val| {
        const body = if (cond_val.toBool()) &inst.positionals.then_body else &inst.positionals.else_body;
        try analyzeBody(mod, parent_block, body.*);
        return mod.constNoReturn(scope, inst.base.src);
    }

    var true_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    defer true_block.instructions.deinit(mod.gpa);
    try analyzeBody(mod, &true_block, inst.positionals.then_body);

    var false_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    defer false_block.instructions.deinit(mod.gpa);
    try analyzeBody(mod, &false_block, inst.positionals.else_body);

    const then_body: ir.Body = .{ .instructions = try scope.arena().dupe(*Inst, true_block.instructions.items) };
    const else_body: ir.Body = .{ .instructions = try scope.arena().dupe(*Inst, false_block.instructions.items) };
    return mod.addCondBr(parent_block, inst.base.src, cond, then_body, else_body);
}

fn zirUnreachable(
    mod: *Module,
    scope: *Scope,
    unreach: *zir.Inst.NoOp,
    safety_check: bool,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireRuntimeBlock(scope, unreach.base.src);
    // TODO Add compile error for @optimizeFor occurring too late in a scope.
    if (safety_check and mod.wantSafety(scope)) {
        return mod.safetyPanic(b, unreach.base.src, .unreach);
    } else {
        return mod.addNoOp(b, unreach.base.src, Type.initTag(.noreturn), .unreach);
    }
}

fn zirReturn(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    const b = try mod.requireFunctionBlock(scope, inst.base.src);

    if (b.inlining) |inlining| {
        // We are inlining a function call; rewrite the `ret` as a `break`.
        try inlining.merges.results.append(mod.gpa, operand);
        const br = try mod.addBr(b, inst.base.src, inlining.merges.block_inst, operand);
        return &br.base;
    }

    return mod.addUnOp(b, inst.base.src, Type.initTag(.noreturn), .ret, operand);
}

fn zirReturnVoid(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    if (b.inlining) |inlining| {
        // We are inlining a function call; rewrite the `retvoid` as a `breakvoid`.
        const void_inst = try mod.constVoid(scope, inst.base.src);
        try inlining.merges.results.append(mod.gpa, void_inst);
        const br = try mod.addBr(b, inst.base.src, inlining.merges.block_inst, void_inst);
        return &br.base;
    }

    if (b.func) |func| {
        // Need to emit a compile error if returning void is not allowed.
        const void_inst = try mod.constVoid(scope, inst.base.src);
        const fn_ty = func.owner_decl.typed_value.most_recent.typed_value.ty;
        const casted_void = try mod.coerce(scope, fn_ty.fnReturnType(), void_inst);
        if (casted_void.ty.zigTypeTag() != .Void) {
            return mod.addUnOp(b, inst.base.src, Type.initTag(.noreturn), .ret, casted_void);
        }
    }
    return mod.addNoOp(b, inst.base.src, Type.initTag(.noreturn), .retvoid);
}

fn floatOpAllowed(tag: zir.Inst.Tag) bool {
    // extend this swich as additional operators are implemented
    return switch (tag) {
        .add, .sub => true,
        else => false,
    };
}

fn zirSimplePtrType(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, mutable: bool, size: std.builtin.TypeInfo.Pointer.Size) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const elem_type = try resolveType(mod, scope, inst.positionals.operand);
    const ty = try mod.simplePtrType(scope, inst.base.src, elem_type, mutable, size);
    return mod.constType(scope, inst.base.src, ty);
}

fn zirPtrType(mod: *Module, scope: *Scope, inst: *zir.Inst.PtrType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO lazy values
    const @"align" = if (inst.kw_args.@"align") |some|
        @truncate(u32, try resolveInt(mod, scope, some, Type.initTag(.u32)))
    else
        0;
    const bit_offset = if (inst.kw_args.align_bit_start) |some|
        @truncate(u16, try resolveInt(mod, scope, some, Type.initTag(.u16)))
    else
        0;
    const host_size = if (inst.kw_args.align_bit_end) |some|
        @truncate(u16, try resolveInt(mod, scope, some, Type.initTag(.u16)))
    else
        0;

    if (host_size != 0 and bit_offset >= host_size * 8)
        return mod.fail(scope, inst.base.src, "bit offset starts after end of host integer", .{});

    const sentinel = if (inst.kw_args.sentinel) |some|
        (try resolveInstConst(mod, scope, some)).val
    else
        null;

    const elem_type = try resolveType(mod, scope, inst.positionals.child_type);

    const ty = try mod.ptrType(
        scope,
        inst.base.src,
        elem_type,
        sentinel,
        @"align",
        bit_offset,
        host_size,
        inst.kw_args.mutable,
        inst.kw_args.@"allowzero",
        inst.kw_args.@"volatile",
        inst.kw_args.size,
    );
    return mod.constType(scope, inst.base.src, ty);
}
