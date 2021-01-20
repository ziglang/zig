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
        .alloc => return analyzeInstAlloc(mod, scope, old_inst.castTag(.alloc).?),
        .alloc_mut => return analyzeInstAllocMut(mod, scope, old_inst.castTag(.alloc_mut).?),
        .alloc_inferred => return analyzeInstAllocInferred(
            mod,
            scope,
            old_inst.castTag(.alloc_inferred).?,
            .inferred_alloc_const,
        ),
        .alloc_inferred_mut => return analyzeInstAllocInferred(
            mod,
            scope,
            old_inst.castTag(.alloc_inferred_mut).?,
            .inferred_alloc_mut,
        ),
        .arg => return analyzeInstArg(mod, scope, old_inst.castTag(.arg).?),
        .bitcast_ref => return bitCastRef(mod, scope, old_inst.castTag(.bitcast_ref).?),
        .bitcast_result_ptr => return bitCastResultPtr(mod, scope, old_inst.castTag(.bitcast_result_ptr).?),
        .block => return analyzeInstBlock(mod, scope, old_inst.castTag(.block).?, false),
        .block_comptime => return analyzeInstBlock(mod, scope, old_inst.castTag(.block_comptime).?, true),
        .block_flat => return analyzeInstBlockFlat(mod, scope, old_inst.castTag(.block_flat).?, false),
        .block_comptime_flat => return analyzeInstBlockFlat(mod, scope, old_inst.castTag(.block_comptime_flat).?, true),
        .@"break" => return analyzeInstBreak(mod, scope, old_inst.castTag(.@"break").?),
        .breakpoint => return analyzeInstBreakpoint(mod, scope, old_inst.castTag(.breakpoint).?),
        .breakvoid => return analyzeInstBreakVoid(mod, scope, old_inst.castTag(.breakvoid).?),
        .call => return call(mod, scope, old_inst.castTag(.call).?),
        .coerce_result_block_ptr => return analyzeInstCoerceResultBlockPtr(mod, scope, old_inst.castTag(.coerce_result_block_ptr).?),
        .coerce_result_ptr => return analyzeInstCoerceResultPtr(mod, scope, old_inst.castTag(.coerce_result_ptr).?),
        .coerce_to_ptr_elem => return analyzeInstCoerceToPtrElem(mod, scope, old_inst.castTag(.coerce_to_ptr_elem).?),
        .compileerror => return analyzeInstCompileError(mod, scope, old_inst.castTag(.compileerror).?),
        .compilelog => return analyzeInstCompileLog(mod, scope, old_inst.castTag(.compilelog).?),
        .@"const" => return analyzeInstConst(mod, scope, old_inst.castTag(.@"const").?),
        .dbg_stmt => return analyzeInstDbgStmt(mod, scope, old_inst.castTag(.dbg_stmt).?),
        .declref => return declRef(mod, scope, old_inst.castTag(.declref).?),
        .declref_str => return analyzeInstDeclRefStr(mod, scope, old_inst.castTag(.declref_str).?),
        .declval => return declVal(mod, scope, old_inst.castTag(.declval).?),
        .ensure_result_used => return analyzeInstEnsureResultUsed(mod, scope, old_inst.castTag(.ensure_result_used).?),
        .ensure_result_non_error => return analyzeInstEnsureResultNonError(mod, scope, old_inst.castTag(.ensure_result_non_error).?),
        .indexable_ptr_len => return indexablePtrLen(mod, scope, old_inst.castTag(.indexable_ptr_len).?),
        .ref => return ref(mod, scope, old_inst.castTag(.ref).?),
        .resolve_inferred_alloc => return analyzeInstResolveInferredAlloc(mod, scope, old_inst.castTag(.resolve_inferred_alloc).?),
        .ret_ptr => return analyzeInstRetPtr(mod, scope, old_inst.castTag(.ret_ptr).?),
        .ret_type => return analyzeInstRetType(mod, scope, old_inst.castTag(.ret_type).?),
        .store_to_inferred_ptr => return analyzeInstStoreToInferredPtr(mod, scope, old_inst.castTag(.store_to_inferred_ptr).?),
        .single_const_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.single_const_ptr_type).?, false, .One),
        .single_mut_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.single_mut_ptr_type).?, true, .One),
        .many_const_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.many_const_ptr_type).?, false, .Many),
        .many_mut_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.many_mut_ptr_type).?, true, .Many),
        .c_const_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.c_const_ptr_type).?, false, .C),
        .c_mut_ptr_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.c_mut_ptr_type).?, true, .C),
        .const_slice_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.const_slice_type).?, false, .Slice),
        .mut_slice_type => return analyzeInstSimplePtrType(mod, scope, old_inst.castTag(.mut_slice_type).?, true, .Slice),
        .ptr_type => return analyzeInstPtrType(mod, scope, old_inst.castTag(.ptr_type).?),
        .store => return analyzeInstStore(mod, scope, old_inst.castTag(.store).?),
        .set_eval_branch_quota => return analyzeInstSetEvalBranchQuota(mod, scope, old_inst.castTag(.set_eval_branch_quota).?),
        .str => return analyzeInstStr(mod, scope, old_inst.castTag(.str).?),
        .int => return analyzeInstInt(mod, scope, old_inst.castTag(.int).?),
        .inttype => return analyzeInstIntType(mod, scope, old_inst.castTag(.inttype).?),
        .loop => return analyzeInstLoop(mod, scope, old_inst.castTag(.loop).?),
        .param_type => return analyzeInstParamType(mod, scope, old_inst.castTag(.param_type).?),
        .ptrtoint => return analyzeInstPtrToInt(mod, scope, old_inst.castTag(.ptrtoint).?),
        .field_ptr => return fieldPtr(mod, scope, old_inst.castTag(.field_ptr).?),
        .field_val => return fieldVal(mod, scope, old_inst.castTag(.field_val).?),
        .field_ptr_named => return fieldPtrNamed(mod, scope, old_inst.castTag(.field_ptr_named).?),
        .field_val_named => return fieldValNamed(mod, scope, old_inst.castTag(.field_val_named).?),
        .deref => return analyzeInstDeref(mod, scope, old_inst.castTag(.deref).?),
        .as => return analyzeInstAs(mod, scope, old_inst.castTag(.as).?),
        .@"asm" => return analyzeInstAsm(mod, scope, old_inst.castTag(.@"asm").?),
        .@"unreachable" => return analyzeInstUnreachable(mod, scope, old_inst.castTag(.@"unreachable").?, true),
        .unreach_nocheck => return analyzeInstUnreachable(mod, scope, old_inst.castTag(.unreach_nocheck).?, false),
        .@"return" => return analyzeInstRet(mod, scope, old_inst.castTag(.@"return").?),
        .returnvoid => return analyzeInstRetVoid(mod, scope, old_inst.castTag(.returnvoid).?),
        .@"fn" => return analyzeInstFn(mod, scope, old_inst.castTag(.@"fn").?),
        .@"export" => return analyzeInstExport(mod, scope, old_inst.castTag(.@"export").?),
        .primitive => return analyzeInstPrimitive(mod, scope, old_inst.castTag(.primitive).?),
        .fntype => return analyzeInstFnType(mod, scope, old_inst.castTag(.fntype).?),
        .intcast => return analyzeInstIntCast(mod, scope, old_inst.castTag(.intcast).?),
        .bitcast => return analyzeInstBitCast(mod, scope, old_inst.castTag(.bitcast).?),
        .floatcast => return analyzeInstFloatCast(mod, scope, old_inst.castTag(.floatcast).?),
        .elem_ptr => return elemPtr(mod, scope, old_inst.castTag(.elem_ptr).?),
        .elem_val => return elemVal(mod, scope, old_inst.castTag(.elem_val).?),
        .add => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.add).?),
        .addwrap => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.addwrap).?),
        .sub => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.sub).?),
        .subwrap => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.subwrap).?),
        .mul => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.mul).?),
        .mulwrap => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.mulwrap).?),
        .div => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.div).?),
        .mod_rem => return analyzeInstArithmetic(mod, scope, old_inst.castTag(.mod_rem).?),
        .array_cat => return analyzeInstArrayCat(mod, scope, old_inst.castTag(.array_cat).?),
        .array_mul => return analyzeInstArrayMul(mod, scope, old_inst.castTag(.array_mul).?),
        .bitand => return analyzeInstBitwise(mod, scope, old_inst.castTag(.bitand).?),
        .bitnot => return analyzeInstBitNot(mod, scope, old_inst.castTag(.bitnot).?),
        .bitor => return analyzeInstBitwise(mod, scope, old_inst.castTag(.bitor).?),
        .xor => return analyzeInstBitwise(mod, scope, old_inst.castTag(.xor).?),
        .shl => return analyzeInstShl(mod, scope, old_inst.castTag(.shl).?),
        .shr => return analyzeInstShr(mod, scope, old_inst.castTag(.shr).?),
        .cmp_lt => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_lt).?, .lt),
        .cmp_lte => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_lte).?, .lte),
        .cmp_eq => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_eq).?, .eq),
        .cmp_gte => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_gte).?, .gte),
        .cmp_gt => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_gt).?, .gt),
        .cmp_neq => return analyzeInstCmp(mod, scope, old_inst.castTag(.cmp_neq).?, .neq),
        .condbr => return analyzeInstCondBr(mod, scope, old_inst.castTag(.condbr).?),
        .is_null => return isNull(mod, scope, old_inst.castTag(.is_null).?, false),
        .is_non_null => return isNull(mod, scope, old_inst.castTag(.is_non_null).?, true),
        .is_null_ptr => return isNullPtr(mod, scope, old_inst.castTag(.is_null_ptr).?, false),
        .is_non_null_ptr => return isNullPtr(mod, scope, old_inst.castTag(.is_non_null_ptr).?, true),
        .is_err => return isErr(mod, scope, old_inst.castTag(.is_err).?),
        .is_err_ptr => return isErrPtr(mod, scope, old_inst.castTag(.is_err_ptr).?),
        .boolnot => return analyzeInstBoolNot(mod, scope, old_inst.castTag(.boolnot).?),
        .typeof => return analyzeInstTypeOf(mod, scope, old_inst.castTag(.typeof).?),
        .typeof_peer => return analyzeInstTypeOfPeer(mod, scope, old_inst.castTag(.typeof_peer).?),
        .optional_type => return analyzeInstOptionalType(mod, scope, old_inst.castTag(.optional_type).?),
        .optional_payload_safe => return optionalPayload(mod, scope, old_inst.castTag(.optional_payload_safe).?, true),
        .optional_payload_unsafe => return optionalPayload(mod, scope, old_inst.castTag(.optional_payload_unsafe).?, false),
        .optional_payload_safe_ptr => return optionalPayloadPtr(mod, scope, old_inst.castTag(.optional_payload_safe_ptr).?, true),
        .optional_payload_unsafe_ptr => return optionalPayloadPtr(mod, scope, old_inst.castTag(.optional_payload_unsafe_ptr).?, false),
        .err_union_payload_safe => return errorUnionPayload(mod, scope, old_inst.castTag(.err_union_payload_safe).?, true),
        .err_union_payload_unsafe => return errorUnionPayload(mod, scope, old_inst.castTag(.err_union_payload_unsafe).?, false),
        .err_union_payload_safe_ptr => return errorUnionPayloadPtr(mod, scope, old_inst.castTag(.err_union_payload_safe_ptr).?, true),
        .err_union_payload_unsafe_ptr => return errorUnionPayloadPtr(mod, scope, old_inst.castTag(.err_union_payload_unsafe_ptr).?, false),
        .err_union_code => return errorUnionCode(mod, scope, old_inst.castTag(.err_union_code).?),
        .err_union_code_ptr => return errorUnionCodePtr(mod, scope, old_inst.castTag(.err_union_code_ptr).?),
        .ensure_err_payload_void => return analyzeInstEnsureErrPayloadVoid(mod, scope, old_inst.castTag(.ensure_err_payload_void).?),
        .array_type => return analyzeInstArrayType(mod, scope, old_inst.castTag(.array_type).?),
        .array_type_sentinel => return analyzeInstArrayTypeSentinel(mod, scope, old_inst.castTag(.array_type_sentinel).?),
        .enum_literal => return analyzeInstEnumLiteral(mod, scope, old_inst.castTag(.enum_literal).?),
        .merge_error_sets => return analyzeInstMergeErrorSets(mod, scope, old_inst.castTag(.merge_error_sets).?),
        .error_union_type => return analyzeInstErrorUnionType(mod, scope, old_inst.castTag(.error_union_type).?),
        .anyframe_type => return analyzeInstAnyframeType(mod, scope, old_inst.castTag(.anyframe_type).?),
        .error_set => return analyzeInstErrorSet(mod, scope, old_inst.castTag(.error_set).?),
        .slice => return analyzeInstSlice(mod, scope, old_inst.castTag(.slice).?),
        .slice_start => return analyzeInstSliceStart(mod, scope, old_inst.castTag(.slice_start).?),
        .import => return analyzeInstImport(mod, scope, old_inst.castTag(.import).?),
        .switchbr => return analyzeInstSwitchBr(mod, scope, old_inst.castTag(.switchbr).?),
        .switch_range => return analyzeInstSwitchRange(mod, scope, old_inst.castTag(.switch_range).?),
        .booland => return analyzeInstBoolOp(mod, scope, old_inst.castTag(.booland).?),
        .boolor => return analyzeInstBoolOp(mod, scope, old_inst.castTag(.boolor).?),

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

fn analyzeInstConst(mod: *Module, scope: *Scope, const_inst: *zir.Inst.Const) InnerError!*Inst {
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

fn analyzeInstCoerceResultBlockPtr(
    mod: *Module,
    scope: *Scope,
    inst: *zir.Inst.CoerceResultBlockPtr,
) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstCoerceResultBlockPtr", .{});
}

fn bitCastRef(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zir_sema.bitCastRef", .{});
}

fn bitCastResultPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement zir_sema.bitCastResultPtr", .{});
}

fn analyzeInstCoerceResultPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstCoerceResultPtr", .{});
}

/// Equivalent to `as(ptr_child_type(typeof(ptr)), value)`.
fn analyzeInstCoerceToPtrElem(mod: *Module, scope: *Scope, inst: *zir.Inst.CoerceToPtrElem) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.ptr);
    const operand = try resolveInst(mod, scope, inst.positionals.value);
    return mod.coerce(scope, ptr.ty.elemType(), operand);
}

fn analyzeInstRetPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, ret_type, true, .One);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn ref(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeRef(scope, inst.base.src, operand);
}

fn analyzeInstRetType(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const ret_type = fn_ty.fnReturnType();
    return mod.constType(scope, inst.base.src, ret_type);
}

fn analyzeInstEnsureResultUsed(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    switch (operand.ty.zigTypeTag()) {
        .Void, .NoReturn => return mod.constVoid(scope, operand.src),
        else => return mod.fail(scope, operand.src, "expression value is ignored", .{}),
    }
}

fn analyzeInstEnsureResultNonError(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    switch (operand.ty.zigTypeTag()) {
        .ErrorSet, .ErrorUnion => return mod.fail(scope, operand.src, "error is discarded", .{}),
        else => return mod.constVoid(scope, operand.src),
    }
}

fn indexablePtrLen(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
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

fn analyzeInstAlloc(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const var_type = try resolveType(mod, scope, inst.positionals.operand);
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, var_type, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn analyzeInstAllocMut(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const var_type = try resolveType(mod, scope, inst.positionals.operand);
    try mod.validateVarType(scope, inst.base.src, var_type);
    const ptr_type = try mod.simplePtrType(scope, inst.base.src, var_type, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, ptr_type, .alloc);
}

fn analyzeInstAllocInferred(
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

fn analyzeInstResolveInferredAlloc(
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

fn analyzeInstStoreToInferredPtr(
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
    // Create a new alloc with exactly the type the pointer wants.
    // Later it gets cleaned up by aliasing the alloc we are supposed to be storing to.
    const ptr_ty = try mod.simplePtrType(scope, inst.base.src, value.ty, true, .One);
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    const bitcasted_ptr = try mod.addUnOp(b, inst.base.src, ptr_ty, .bitcast, ptr);
    return mod.storePtr(scope, inst.base.src, bitcasted_ptr, value);
}

fn analyzeInstSetEvalBranchQuota(
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

fn analyzeInstStore(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const value = try resolveInst(mod, scope, inst.positionals.rhs);
    return mod.storePtr(scope, inst.base.src, ptr, value);
}

fn analyzeInstParamType(mod: *Module, scope: *Scope, inst: *zir.Inst.ParamType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const fn_inst = try resolveInst(mod, scope, inst.positionals.func);
    const arg_index = inst.positionals.arg_index;

    const fn_ty: Type = switch (fn_inst.ty.zigTypeTag()) {
        .Fn => fn_inst.ty,
        .BoundFn => {
            return mod.fail(scope, fn_inst.src, "TODO implement analyzeInstParamType for method call syntax", .{});
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

fn analyzeInstStr(mod: *Module, scope: *Scope, str_inst: *zir.Inst.Str) InnerError!*Inst {
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

fn analyzeInstInt(mod: *Module, scope: *Scope, inst: *zir.Inst.Int) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    return mod.constIntBig(scope, inst.base.src, Type.initTag(.comptime_int), inst.positionals.int);
}

fn analyzeInstExport(mod: *Module, scope: *Scope, export_inst: *zir.Inst.Export) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const symbol_name = try resolveConstString(mod, scope, export_inst.positionals.symbol_name);
    const exported_decl = mod.lookupDeclName(scope, export_inst.positionals.decl_name) orelse
        return mod.fail(scope, export_inst.base.src, "decl '{s}' not found", .{export_inst.positionals.decl_name});
    try mod.analyzeExport(scope, export_inst.base.src, symbol_name, exported_decl);
    return mod.constVoid(scope, export_inst.base.src);
}

fn analyzeInstCompileError(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const msg = try resolveConstString(mod, scope, inst.positionals.operand);
    return mod.fail(scope, inst.base.src, "{s}", .{msg});
}

fn analyzeInstCompileLog(mod: *Module, scope: *Scope, inst: *zir.Inst.CompileLog) InnerError!*Inst {
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

fn analyzeInstArg(mod: *Module, scope: *Scope, inst: *zir.Inst.Arg) InnerError!*Inst {
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

fn analyzeInstLoop(mod: *Module, scope: *Scope, inst: *zir.Inst.Loop) InnerError!*Inst {
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

fn analyzeInstBlockFlat(mod: *Module, scope: *Scope, inst: *zir.Inst.Block, is_comptime: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const parent_block = scope.cast(Scope.Block).?;

    var child_block: Scope.Block = .{
        .parent = parent_block,
        .inst_table = parent_block.inst_table,
        .func = parent_block.func,
        .owner_decl = parent_block.owner_decl,
        .src_decl = parent_block.src_decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .label = null,
        .inlining = parent_block.inlining,
        .is_comptime = parent_block.is_comptime or is_comptime,
        .branch_quota = parent_block.branch_quota,
    };
    defer child_block.instructions.deinit(mod.gpa);

    try analyzeBody(mod, &child_block, inst.positionals.body);

    // Move the analyzed instructions into the parent block arena.
    const copied_instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items);
    try parent_block.instructions.appendSlice(mod.gpa, copied_instructions);

    // The result of a flat block is the last instruction.
    const zir_inst_list = inst.positionals.body.instructions;
    const last_zir_inst = zir_inst_list[zir_inst_list.len - 1];
    return resolveInst(mod, scope, last_zir_inst);
}

fn analyzeInstBlock(mod: *Module, scope: *Scope, inst: *zir.Inst.Block, is_comptime: bool) InnerError!*Inst {
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
                // No need for a block instruction. We can put the new instructions directly into the parent block.
                // Here we omit the break instruction.
                const copied_instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items[0..last_inst_index]);
                try parent_block.instructions.appendSlice(mod.gpa, copied_instructions);
                return merges.results.items[0];
            }
        }
    }
    // It should be impossible to have the number of results be > 1 in a comptime scope.
    assert(!child_block.is_comptime); // We should have already got a compile error in the condbr condition.

    // Need to set the type and emit the Block instruction. This allows machine code generation
    // to emit a jump instruction to after the block when it encounters the break.
    try parent_block.instructions.append(mod.gpa, &merges.block_inst.base);
    merges.block_inst.base.ty = try mod.resolvePeerTypes(scope, merges.results.items);
    merges.block_inst.body = .{ .instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items) };
    return &merges.block_inst.base;
}

fn analyzeInstBreakpoint(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireRuntimeBlock(scope, inst.base.src);
    return mod.addNoOp(b, inst.base.src, Type.initTag(.void), .breakpoint);
}

fn analyzeInstBreak(mod: *Module, scope: *Scope, inst: *zir.Inst.Break) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    const block = inst.positionals.block;
    return analyzeBreak(mod, scope, inst.base.src, block, operand);
}

fn analyzeInstBreakVoid(mod: *Module, scope: *Scope, inst: *zir.Inst.BreakVoid) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const block = inst.positionals.block;
    const void_inst = try mod.constVoid(scope, inst.base.src);
    return analyzeBreak(mod, scope, inst.base.src, block, void_inst);
}

fn analyzeInstDbgStmt(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    if (scope.cast(Scope.Block)) |b| {
        if (!b.is_comptime) {
            return mod.addNoOp(b, inst.base.src, Type.initTag(.void), .dbg_stmt);
        }
    }
    return mod.constVoid(scope, inst.base.src);
}

fn analyzeInstDeclRefStr(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclRefStr) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const decl_name = try resolveConstString(mod, scope, inst.positionals.name);
    return mod.analyzeDeclRefByName(scope, inst.base.src, decl_name);
}

fn declRef(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclRef) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.analyzeDeclRef(scope, inst.base.src, inst.positionals.decl);
}

fn declVal(mod: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.analyzeDeclVal(scope, inst.base.src, inst.positionals.decl);
}

fn call(mod: *Module, scope: *Scope, inst: *zir.Inst.Call) InnerError!*Inst {
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
    const is_inline_call = is_comptime_call or inst.kw_args.modifier == .always_inline or blk: {
        // This logic will get simplified by
        // https://github.com/ziglang/zig/issues/6429
        if (try mod.resolveDefinedValue(scope, func)) |func_val| {
            const module_fn = switch (func_val.tag()) {
                .function => func_val.castTag(.function).?.data,
                else => break :blk false,
            };
            break :blk module_fn.state == .inline_only;
        }
        break :blk false;
    };
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

        try mod.emitBackwardBranch(&child_block, inst.base.src);

        // This will have return instructions analyzed as break instructions to
        // the block_inst above.
        try analyzeBody(mod, &child_block, module_fn.zir);

        return analyzeBlockBody(mod, scope, &child_block, merges);
    }

    return mod.addCall(b, inst.base.src, ret_type, func, casted_args);
}

fn analyzeInstFn(mod: *Module, scope: *Scope, fn_inst: *zir.Inst.Fn) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const fn_type = try resolveType(mod, scope, fn_inst.positionals.fn_type);
    const new_func = try scope.arena().create(Module.Fn);
    new_func.* = .{
        .state = if (fn_inst.kw_args.is_inline) .inline_only else .queued,
        .zir = fn_inst.positionals.body,
        .body = undefined,
        .owner_decl = scope.ownerDecl().?,
    };
    return mod.constInst(scope, fn_inst.base.src, .{
        .ty = fn_type,
        .val = try Value.Tag.function.create(scope.arena(), new_func),
    });
}

fn analyzeInstIntType(mod: *Module, scope: *Scope, inttype: *zir.Inst.IntType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inttype.base.src, "TODO implement inttype", .{});
}

fn analyzeInstOptionalType(mod: *Module, scope: *Scope, optional: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const child_type = try resolveType(mod, scope, optional.positionals.operand);

    return mod.constType(scope, optional.base.src, try mod.optionalType(scope, child_type));
}

fn analyzeInstArrayType(mod: *Module, scope: *Scope, array: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO these should be lazily evaluated
    const len = try resolveInstConst(mod, scope, array.positionals.lhs);
    const elem_type = try resolveType(mod, scope, array.positionals.rhs);

    return mod.constType(scope, array.base.src, try mod.arrayType(scope, len.val.toUnsignedInt(), null, elem_type));
}

fn analyzeInstArrayTypeSentinel(mod: *Module, scope: *Scope, array: *zir.Inst.ArrayTypeSentinel) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO these should be lazily evaluated
    const len = try resolveInstConst(mod, scope, array.positionals.len);
    const sentinel = try resolveInstConst(mod, scope, array.positionals.sentinel);
    const elem_type = try resolveType(mod, scope, array.positionals.elem_type);

    return mod.constType(scope, array.base.src, try mod.arrayType(scope, len.val.toUnsignedInt(), sentinel.val, elem_type));
}

fn analyzeInstErrorUnionType(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const error_union = try resolveType(mod, scope, inst.positionals.lhs);
    const payload = try resolveType(mod, scope, inst.positionals.rhs);

    if (error_union.zigTypeTag() != .ErrorSet) {
        return mod.fail(scope, inst.base.src, "expected error set type, found {}", .{error_union.elemType()});
    }

    return mod.constType(scope, inst.base.src, try mod.errorUnionType(scope, error_union, payload));
}

fn analyzeInstAnyframeType(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const return_type = try resolveType(mod, scope, inst.positionals.operand);

    return mod.constType(scope, inst.base.src, try mod.anyframeType(scope, return_type));
}

fn analyzeInstErrorSet(mod: *Module, scope: *Scope, inst: *zir.Inst.ErrorSet) InnerError!*Inst {
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

fn analyzeInstMergeErrorSets(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement merge_error_sets", .{});
}

fn analyzeInstEnumLiteral(mod: *Module, scope: *Scope, inst: *zir.Inst.EnumLiteral) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const duped_name = try scope.arena().dupe(u8, inst.positionals.name);
    return mod.constInst(scope, inst.base.src, .{
        .ty = Type.initTag(.enum_literal),
        .val = try Value.Tag.enum_literal.create(scope.arena(), duped_name),
    });
}

/// Pointer in, pointer out.
fn optionalPayloadPtr(
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
fn optionalPayload(
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
fn errorUnionPayload(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp, safety_check: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.errorUnionPayload", .{});
}

/// Pointer in, pointer out
fn errorUnionPayloadPtr(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp, safety_check: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.errorUnionPayloadPtr", .{});
}

/// Value in, value out
fn errorUnionCode(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.errorUnionCode", .{});
}

/// Pointer in, value out
fn errorUnionCodePtr(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement zir_sema.errorUnionCodePtr", .{});
}

fn analyzeInstEnsureErrPayloadVoid(mod: *Module, scope: *Scope, unwrap: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, unwrap.base.src, "TODO implement analyzeInstEnsureErrPayloadVoid", .{});
}

fn analyzeInstFnType(mod: *Module, scope: *Scope, fntype: *zir.Inst.FnType) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const return_type = try resolveType(mod, scope, fntype.positionals.return_type);

    // Hot path for some common function types.
    if (fntype.positionals.param_types.len == 0) {
        if (return_type.zigTypeTag() == .NoReturn and fntype.kw_args.cc == .Unspecified) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and fntype.kw_args.cc == .Unspecified) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_void_no_args));
        }

        if (return_type.zigTypeTag() == .NoReturn and fntype.kw_args.cc == .Naked) {
            return mod.constType(scope, fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and fntype.kw_args.cc == .C) {
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
        .cc = fntype.kw_args.cc,
        .return_type = return_type,
        .param_types = param_types,
    });
    return mod.constType(scope, fntype.base.src, fn_ty);
}

fn analyzeInstPrimitive(mod: *Module, scope: *Scope, primitive: *zir.Inst.Primitive) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.constInst(scope, primitive.base.src, primitive.positionals.tag.toTypedValue());
}

fn analyzeInstAs(mod: *Module, scope: *Scope, as: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, as.positionals.lhs);
    const new_inst = try resolveInst(mod, scope, as.positionals.rhs);
    return mod.coerce(scope, dest_type, new_inst);
}

fn analyzeInstPtrToInt(mod: *Module, scope: *Scope, ptrtoint: *zir.Inst.UnOp) InnerError!*Inst {
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

fn fieldVal(mod: *Module, scope: *Scope, inst: *zir.Inst.Field) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = inst.positionals.field_name;
    const object_ptr = try mod.analyzeRef(scope, inst.base.src, object);
    const result_ptr = try mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, inst.base.src);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn fieldPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.Field) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object_ptr = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = inst.positionals.field_name;
    return mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, inst.base.src);
}

fn fieldValNamed(mod: *Module, scope: *Scope, inst: *zir.Inst.FieldNamed) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = try resolveConstString(mod, scope, inst.positionals.field_name);
    const fsrc = inst.positionals.field_name.src;
    const object_ptr = try mod.analyzeRef(scope, inst.base.src, object);
    const result_ptr = try mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, fsrc);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn fieldPtrNamed(mod: *Module, scope: *Scope, inst: *zir.Inst.FieldNamed) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const object_ptr = try resolveInst(mod, scope, inst.positionals.object);
    const field_name = try resolveConstString(mod, scope, inst.positionals.field_name);
    const fsrc = inst.positionals.field_name.src;
    return mod.namedFieldPtr(scope, inst.base.src, object_ptr, field_name, fsrc);
}

fn analyzeInstIntCast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
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

fn analyzeInstBitCast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const dest_type = try resolveType(mod, scope, inst.positionals.lhs);
    const operand = try resolveInst(mod, scope, inst.positionals.rhs);
    return mod.bitcast(scope, dest_type, operand);
}

fn analyzeInstFloatCast(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
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

fn elemVal(mod: *Module, scope: *Scope, inst: *zir.Inst.Elem) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const array = try resolveInst(mod, scope, inst.positionals.array);
    const array_ptr = try mod.analyzeRef(scope, inst.base.src, array);
    const elem_index = try resolveInst(mod, scope, inst.positionals.index);
    const result_ptr = try mod.elemPtr(scope, inst.base.src, array_ptr, elem_index);
    return mod.analyzeDeref(scope, inst.base.src, result_ptr, result_ptr.src);
}

fn elemPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.Elem) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const array_ptr = try resolveInst(mod, scope, inst.positionals.array);
    const elem_index = try resolveInst(mod, scope, inst.positionals.index);
    return mod.elemPtr(scope, inst.base.src, array_ptr, elem_index);
}

fn analyzeInstSlice(mod: *Module, scope: *Scope, inst: *zir.Inst.Slice) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const array_ptr = try resolveInst(mod, scope, inst.positionals.array_ptr);
    const start = try resolveInst(mod, scope, inst.positionals.start);
    const end = if (inst.kw_args.end) |end| try resolveInst(mod, scope, end) else null;
    const sentinel = if (inst.kw_args.sentinel) |sentinel| try resolveInst(mod, scope, sentinel) else null;

    return mod.analyzeSlice(scope, inst.base.src, array_ptr, start, end, sentinel);
}

fn analyzeInstSliceStart(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const array_ptr = try resolveInst(mod, scope, inst.positionals.lhs);
    const start = try resolveInst(mod, scope, inst.positionals.rhs);

    return mod.analyzeSlice(scope, inst.base.src, array_ptr, start, null, null);
}

fn analyzeInstSwitchRange(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
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
    if (start.value()) |start_val| {
        if (end.value()) |end_val| {
            if (start_val.compare(.gte, end_val)) {
                return mod.fail(scope, inst.base.src, "range start value must be smaller than the end value", .{});
            }
        }
    }
    return mod.constVoid(scope, inst.base.src);
}

fn analyzeInstSwitchBr(mod: *Module, scope: *Scope, inst: *zir.Inst.SwitchBr) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const target_ptr = try resolveInst(mod, scope, inst.positionals.target_ptr);
    const target = try mod.analyzeDeref(scope, inst.base.src, target_ptr, inst.positionals.target_ptr.src);
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

    return mod.addSwitchBr(parent_block, inst.base.src, target_ptr, cases, else_body);
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

fn analyzeInstImport(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
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

fn analyzeInstShl(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstShl", .{});
}

fn analyzeInstShr(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstShr", .{});
}

fn analyzeInstBitwise(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
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
        return mod.fail(scope, inst.base.src, "invalid operands to binary bitwise expression: '{}' and '{}'", .{ @tagName(lhs.ty.zigTypeTag()), @tagName(rhs.ty.zigTypeTag()) });
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
        .bitand => Inst.Tag.bitand,
        .bitor => Inst.Tag.bitor,
        .xor => Inst.Tag.xor,
        else => unreachable,
    };

    return mod.addBinOp(b, inst.base.src, scalar_type, ir_tag, casted_lhs, casted_rhs);
}

fn analyzeInstBitNot(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstBitNot", .{});
}

fn analyzeInstArrayCat(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstArrayCat", .{});
}

fn analyzeInstArrayMul(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    return mod.fail(scope, inst.base.src, "TODO implement analyzeInstArrayMul", .{});
}

fn analyzeInstArithmetic(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
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

fn analyzeInstDeref(mod: *Module, scope: *Scope, deref: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, deref.positionals.operand);
    return mod.analyzeDeref(scope, deref.base.src, ptr, deref.positionals.operand.src);
}

fn analyzeInstAsm(mod: *Module, scope: *Scope, assembly: *zir.Inst.Asm) InnerError!*Inst {
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

fn analyzeInstCmp(
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

fn analyzeInstTypeOf(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.constType(scope, inst.base.src, operand.ty);
}

fn analyzeInstTypeOfPeer(mod: *Module, scope: *Scope, inst: *zir.Inst.TypeOfPeer) InnerError!*Inst {
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

fn analyzeInstBoolNot(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
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

fn analyzeInstBoolOp(mod: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const bool_type = Type.initTag(.bool);
    const uncasted_lhs = try resolveInst(mod, scope, inst.positionals.lhs);
    const lhs = try mod.coerce(scope, bool_type, uncasted_lhs);
    const uncasted_rhs = try resolveInst(mod, scope, inst.positionals.rhs);
    const rhs = try mod.coerce(scope, bool_type, uncasted_rhs);

    const is_bool_or = inst.base.tag == .boolor;

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
    return mod.addBinOp(b, inst.base.src, bool_type, if (is_bool_or) .boolor else .booland, lhs, rhs);
}

fn isNull(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, invert_logic: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeIsNull(scope, inst.base.src, operand, invert_logic);
}

fn isNullPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, invert_logic: bool) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const loaded = try mod.analyzeDeref(scope, inst.base.src, ptr, ptr.src);
    return mod.analyzeIsNull(scope, inst.base.src, loaded, invert_logic);
}

fn isErr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    return mod.analyzeIsErr(scope, inst.base.src, operand);
}

fn isErrPtr(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const ptr = try resolveInst(mod, scope, inst.positionals.operand);
    const loaded = try mod.analyzeDeref(scope, inst.base.src, ptr, ptr.src);
    return mod.analyzeIsErr(scope, inst.base.src, loaded);
}

fn analyzeInstCondBr(mod: *Module, scope: *Scope, inst: *zir.Inst.CondBr) InnerError!*Inst {
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

fn analyzeInstUnreachable(
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

fn analyzeInstRet(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const operand = try resolveInst(mod, scope, inst.positionals.operand);
    const b = try mod.requireFunctionBlock(scope, inst.base.src);

    if (b.inlining) |inlining| {
        // We are inlining a function call; rewrite the `ret` as a `break`.
        try inlining.merges.results.append(mod.gpa, operand);
        return mod.addBr(b, inst.base.src, inlining.merges.block_inst, operand);
    }

    return mod.addUnOp(b, inst.base.src, Type.initTag(.noreturn), .ret, operand);
}

fn analyzeInstRetVoid(mod: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const b = try mod.requireFunctionBlock(scope, inst.base.src);
    if (b.inlining) |inlining| {
        // We are inlining a function call; rewrite the `retvoid` as a `breakvoid`.
        const void_inst = try mod.constVoid(scope, inst.base.src);
        try inlining.merges.results.append(mod.gpa, void_inst);
        return mod.addBr(b, inst.base.src, inlining.merges.block_inst, void_inst);
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
                try label.merges.results.append(mod.gpa, operand);
                const b = try mod.requireFunctionBlock(scope, src);
                return mod.addBr(b, src, label.merges.block_inst, operand);
            }
        }
        opt_block = block.parent;
    } else unreachable;
}

fn analyzeInstSimplePtrType(mod: *Module, scope: *Scope, inst: *zir.Inst.UnOp, mutable: bool, size: std.builtin.TypeInfo.Pointer.Size) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();
    const elem_type = try resolveType(mod, scope, inst.positionals.operand);
    const ty = try mod.simplePtrType(scope, inst.base.src, elem_type, mutable, size);
    return mod.constType(scope, inst.base.src, ty);
}

fn analyzeInstPtrType(mod: *Module, scope: *Scope, inst: *zir.Inst.PtrType) InnerError!*Inst {
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
