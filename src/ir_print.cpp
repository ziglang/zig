/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"

static uint32_t hash_instruction_ptr(IrInstruction* instruction) {
    return (uint32_t)(uintptr_t)instruction;
}

static bool instruction_ptr_equal(IrInstruction* a, IrInstruction* b) {
    return a == b;
}

using InstructionSet = HashMap<IrInstruction*, uint8_t, hash_instruction_ptr, instruction_ptr_equal>;
using InstructionList = ZigList<IrInstruction*>;

struct IrPrint {
    IrPass pass;
    CodeGen *codegen;
    FILE *f;
    int indent;
    int indent_size;

    // When printing pass 2 instructions referenced var instructions are not
    // present in the instruction list. Thus we track which instructions
    // are printed (per executable) and after each pass 2 instruction those
    // var instructions are rendered in a trailing fashion.
    InstructionSet printed;
    InstructionList pending;
};

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction);

const char* ir_instruction_type_str(IrInstructionId id) {
    switch (id) {
        case IrInstructionIdInvalid:
            return "Invalid";
        case IrInstructionIdShuffleVector:
            return "Shuffle";
        case IrInstructionIdSplatSrc:
            return "SplatSrc";
        case IrInstructionIdSplatGen:
            return "SplatGen";
        case IrInstructionIdDeclVarSrc:
            return "DeclVarSrc";
        case IrInstructionIdDeclVarGen:
            return "DeclVarGen";
        case IrInstructionIdBr:
            return "Br";
        case IrInstructionIdCondBr:
            return "CondBr";
        case IrInstructionIdSwitchBr:
            return "SwitchBr";
        case IrInstructionIdSwitchVar:
            return "SwitchVar";
        case IrInstructionIdSwitchElseVar:
            return "SwitchElseVar";
        case IrInstructionIdSwitchTarget:
            return "SwitchTarget";
        case IrInstructionIdPhi:
            return "Phi";
        case IrInstructionIdUnOp:
            return "UnOp";
        case IrInstructionIdBinOp:
            return "BinOp";
        case IrInstructionIdMergeErrSets:
            return "MergeErrSets";
        case IrInstructionIdLoadPtr:
            return "LoadPtr";
        case IrInstructionIdLoadPtrGen:
            return "LoadPtrGen";
        case IrInstructionIdStorePtr:
            return "StorePtr";
        case IrInstructionIdVectorStoreElem:
            return "VectorStoreElem";
        case IrInstructionIdFieldPtr:
            return "FieldPtr";
        case IrInstructionIdStructFieldPtr:
            return "StructFieldPtr";
        case IrInstructionIdUnionFieldPtr:
            return "UnionFieldPtr";
        case IrInstructionIdElemPtr:
            return "ElemPtr";
        case IrInstructionIdVarPtr:
            return "VarPtr";
        case IrInstructionIdReturnPtr:
            return "ReturnPtr";
        case IrInstructionIdCallExtra:
            return "CallExtra";
        case IrInstructionIdCallSrc:
            return "CallSrc";
        case IrInstructionIdCallSrcArgs:
            return "CallSrcArgs";
        case IrInstructionIdCallGen:
            return "CallGen";
        case IrInstructionIdConst:
            return "Const";
        case IrInstructionIdReturn:
            return "Return";
        case IrInstructionIdCast:
            return "Cast";
        case IrInstructionIdResizeSlice:
            return "ResizeSlice";
        case IrInstructionIdContainerInitList:
            return "ContainerInitList";
        case IrInstructionIdContainerInitFields:
            return "ContainerInitFields";
        case IrInstructionIdUnreachable:
            return "Unreachable";
        case IrInstructionIdTypeOf:
            return "TypeOf";
        case IrInstructionIdSetCold:
            return "SetCold";
        case IrInstructionIdSetRuntimeSafety:
            return "SetRuntimeSafety";
        case IrInstructionIdSetFloatMode:
            return "SetFloatMode";
        case IrInstructionIdArrayType:
            return "ArrayType";
        case IrInstructionIdAnyFrameType:
            return "AnyFrameType";
        case IrInstructionIdSliceType:
            return "SliceType";
        case IrInstructionIdAsmSrc:
            return "AsmSrc";
        case IrInstructionIdAsmGen:
            return "AsmGen";
        case IrInstructionIdSizeOf:
            return "SizeOf";
        case IrInstructionIdTestNonNull:
            return "TestNonNull";
        case IrInstructionIdOptionalUnwrapPtr:
            return "OptionalUnwrapPtr";
        case IrInstructionIdOptionalWrap:
            return "OptionalWrap";
        case IrInstructionIdUnionTag:
            return "UnionTag";
        case IrInstructionIdClz:
            return "Clz";
        case IrInstructionIdCtz:
            return "Ctz";
        case IrInstructionIdPopCount:
            return "PopCount";
        case IrInstructionIdBswap:
            return "Bswap";
        case IrInstructionIdBitReverse:
            return "BitReverse";
        case IrInstructionIdImport:
            return "Import";
        case IrInstructionIdCImport:
            return "CImport";
        case IrInstructionIdCInclude:
            return "CInclude";
        case IrInstructionIdCDefine:
            return "CDefine";
        case IrInstructionIdCUndef:
            return "CUndef";
        case IrInstructionIdRef:
            return "Ref";
        case IrInstructionIdRefGen:
            return "RefGen";
        case IrInstructionIdCompileErr:
            return "CompileErr";
        case IrInstructionIdCompileLog:
            return "CompileLog";
        case IrInstructionIdErrName:
            return "ErrName";
        case IrInstructionIdEmbedFile:
            return "EmbedFile";
        case IrInstructionIdCmpxchgSrc:
            return "CmpxchgSrc";
        case IrInstructionIdCmpxchgGen:
            return "CmpxchgGen";
        case IrInstructionIdFence:
            return "Fence";
        case IrInstructionIdTruncate:
            return "Truncate";
        case IrInstructionIdIntCast:
            return "IntCast";
        case IrInstructionIdFloatCast:
            return "FloatCast";
        case IrInstructionIdIntToFloat:
            return "IntToFloat";
        case IrInstructionIdFloatToInt:
            return "FloatToInt";
        case IrInstructionIdBoolToInt:
            return "BoolToInt";
        case IrInstructionIdIntType:
            return "IntType";
        case IrInstructionIdVectorType:
            return "VectorType";
        case IrInstructionIdBoolNot:
            return "BoolNot";
        case IrInstructionIdMemset:
            return "Memset";
        case IrInstructionIdMemcpy:
            return "Memcpy";
        case IrInstructionIdSliceSrc:
            return "SliceSrc";
        case IrInstructionIdSliceGen:
            return "SliceGen";
        case IrInstructionIdMemberCount:
            return "MemberCount";
        case IrInstructionIdMemberType:
            return "MemberType";
        case IrInstructionIdMemberName:
            return "MemberName";
        case IrInstructionIdBreakpoint:
            return "Breakpoint";
        case IrInstructionIdReturnAddress:
            return "ReturnAddress";
        case IrInstructionIdFrameAddress:
            return "FrameAddress";
        case IrInstructionIdFrameHandle:
            return "FrameHandle";
        case IrInstructionIdFrameType:
            return "FrameType";
        case IrInstructionIdFrameSizeSrc:
            return "FrameSizeSrc";
        case IrInstructionIdFrameSizeGen:
            return "FrameSizeGen";
        case IrInstructionIdAlignOf:
            return "AlignOf";
        case IrInstructionIdOverflowOp:
            return "OverflowOp";
        case IrInstructionIdTestErrSrc:
            return "TestErrSrc";
        case IrInstructionIdTestErrGen:
            return "TestErrGen";
        case IrInstructionIdMulAdd:
            return "MulAdd";
        case IrInstructionIdFloatOp:
            return "FloatOp";
        case IrInstructionIdUnwrapErrCode:
            return "UnwrapErrCode";
        case IrInstructionIdUnwrapErrPayload:
            return "UnwrapErrPayload";
        case IrInstructionIdErrWrapCode:
            return "ErrWrapCode";
        case IrInstructionIdErrWrapPayload:
            return "ErrWrapPayload";
        case IrInstructionIdFnProto:
            return "FnProto";
        case IrInstructionIdTestComptime:
            return "TestComptime";
        case IrInstructionIdPtrCastSrc:
            return "PtrCastSrc";
        case IrInstructionIdPtrCastGen:
            return "PtrCastGen";
        case IrInstructionIdBitCastSrc:
            return "BitCastSrc";
        case IrInstructionIdBitCastGen:
            return "BitCastGen";
        case IrInstructionIdWidenOrShorten:
            return "WidenOrShorten";
        case IrInstructionIdIntToPtr:
            return "IntToPtr";
        case IrInstructionIdPtrToInt:
            return "PtrToInt";
        case IrInstructionIdIntToEnum:
            return "IntToEnum";
        case IrInstructionIdEnumToInt:
            return "EnumToInt";
        case IrInstructionIdIntToErr:
            return "IntToErr";
        case IrInstructionIdErrToInt:
            return "ErrToInt";
        case IrInstructionIdCheckSwitchProngs:
            return "CheckSwitchProngs";
        case IrInstructionIdCheckStatementIsVoid:
            return "CheckStatementIsVoid";
        case IrInstructionIdTypeName:
            return "TypeName";
        case IrInstructionIdDeclRef:
            return "DeclRef";
        case IrInstructionIdPanic:
            return "Panic";
        case IrInstructionIdTagName:
            return "TagName";
        case IrInstructionIdTagType:
            return "TagType";
        case IrInstructionIdFieldParentPtr:
            return "FieldParentPtr";
        case IrInstructionIdByteOffsetOf:
            return "ByteOffsetOf";
        case IrInstructionIdBitOffsetOf:
            return "BitOffsetOf";
        case IrInstructionIdTypeInfo:
            return "TypeInfo";
        case IrInstructionIdType:
            return "Type";
        case IrInstructionIdHasField:
            return "HasField";
        case IrInstructionIdTypeId:
            return "TypeId";
        case IrInstructionIdSetEvalBranchQuota:
            return "SetEvalBranchQuota";
        case IrInstructionIdPtrType:
            return "PtrType";
        case IrInstructionIdAlignCast:
            return "AlignCast";
        case IrInstructionIdImplicitCast:
            return "ImplicitCast";
        case IrInstructionIdResolveResult:
            return "ResolveResult";
        case IrInstructionIdResetResult:
            return "ResetResult";
        case IrInstructionIdOpaqueType:
            return "OpaqueType";
        case IrInstructionIdSetAlignStack:
            return "SetAlignStack";
        case IrInstructionIdArgType:
            return "ArgType";
        case IrInstructionIdExport:
            return "Export";
        case IrInstructionIdErrorReturnTrace:
            return "ErrorReturnTrace";
        case IrInstructionIdErrorUnion:
            return "ErrorUnion";
        case IrInstructionIdAtomicRmw:
            return "AtomicRmw";
        case IrInstructionIdAtomicLoad:
            return "AtomicLoad";
        case IrInstructionIdAtomicStore:
            return "AtomicStore";
        case IrInstructionIdSaveErrRetAddr:
            return "SaveErrRetAddr";
        case IrInstructionIdAddImplicitReturnType:
            return "AddImplicitReturnType";
        case IrInstructionIdErrSetCast:
            return "ErrSetCast";
        case IrInstructionIdToBytes:
            return "ToBytes";
        case IrInstructionIdFromBytes:
            return "FromBytes";
        case IrInstructionIdCheckRuntimeScope:
            return "CheckRuntimeScope";
        case IrInstructionIdVectorToArray:
            return "VectorToArray";
        case IrInstructionIdArrayToVector:
            return "ArrayToVector";
        case IrInstructionIdAssertZero:
            return "AssertZero";
        case IrInstructionIdAssertNonNull:
            return "AssertNonNull";
        case IrInstructionIdHasDecl:
            return "HasDecl";
        case IrInstructionIdUndeclaredIdent:
            return "UndeclaredIdent";
        case IrInstructionIdAllocaSrc:
            return "AllocaSrc";
        case IrInstructionIdAllocaGen:
            return "AllocaGen";
        case IrInstructionIdEndExpr:
            return "EndExpr";
        case IrInstructionIdPtrOfArrayToSlice:
            return "PtrOfArrayToSlice";
        case IrInstructionIdUnionInitNamedField:
            return "UnionInitNamedField";
        case IrInstructionIdSuspendBegin:
            return "SuspendBegin";
        case IrInstructionIdSuspendFinish:
            return "SuspendFinish";
        case IrInstructionIdAwaitSrc:
            return "AwaitSrc";
        case IrInstructionIdAwaitGen:
            return "AwaitGen";
        case IrInstructionIdResume:
            return "Resume";
        case IrInstructionIdSpillBegin:
            return "SpillBegin";
        case IrInstructionIdSpillEnd:
            return "SpillEnd";
        case IrInstructionIdVectorExtractElem:
            return "VectorExtractElem";
    }
    zig_unreachable();
}

static void ir_print_indent(IrPrint *irp) {
    for (int i = 0; i < irp->indent; i += 1) {
        fprintf(irp->f, " ");
    }
}

static void ir_print_prefix(IrPrint *irp, IrInstruction *instruction, bool trailing) {
    ir_print_indent(irp);
    const char mark = trailing ? ':' : '#';
    const char *type_name = instruction->value->type ? buf_ptr(&instruction->value->type->name) : "(unknown)";
    const char *ref_count = ir_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%" PRIu32 "", instruction->ref_count));
    fprintf(irp->f, "%c%-3" PRIu32 "| %-22s| %-12s| %-2s| ", mark, instruction->debug_id,
        ir_instruction_type_str(instruction->id), type_name, ref_count);
}

static void ir_print_const_value(IrPrint *irp, ZigValue *const_val) {
    Buf buf = BUF_INIT;
    buf_resize(&buf, 0);
    render_const_value(irp->codegen, &buf, const_val);
    fprintf(irp->f, "%s", buf_ptr(&buf));
}

static void ir_print_var_instruction(IrPrint *irp, IrInstruction *instruction) {
    fprintf(irp->f, "#%" PRIu32 "", instruction->debug_id);
    if (irp->pass != IrPassSrc && irp->printed.maybe_get(instruction) == nullptr) {
        irp->printed.put(instruction, 0);
        irp->pending.append(instruction);
    }
}

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction) {
    if (instruction == nullptr) {
        fprintf(irp->f, "(null)");
        return;
    }

    if (instruction->value->special != ConstValSpecialRuntime) {
        ir_print_const_value(irp, instruction->value);
    } else {
        ir_print_var_instruction(irp, instruction);
    }
}

static void ir_print_other_block(IrPrint *irp, IrBasicBlock *bb) {
    if (bb == nullptr) {
        fprintf(irp->f, "(null block)");
    } else {
        fprintf(irp->f, "$%s_%" ZIG_PRI_usize "", bb->name_hint, bb->debug_id);
    }
}

static void ir_print_return(IrPrint *irp, IrInstructionReturn *instruction) {
    fprintf(irp->f, "return ");
    ir_print_other_instruction(irp, instruction->operand);
}

static void ir_print_const(IrPrint *irp, IrInstructionConst *const_instruction) {
    ir_print_const_value(irp, const_instruction->base.value);
}

static const char *ir_bin_op_id_str(IrBinOp op_id) {
    switch (op_id) {
        case IrBinOpInvalid:
            zig_unreachable();
        case IrBinOpBoolOr:
            return "BoolOr";
        case IrBinOpBoolAnd:
            return "BoolAnd";
        case IrBinOpCmpEq:
            return "==";
        case IrBinOpCmpNotEq:
            return "!=";
        case IrBinOpCmpLessThan:
            return "<";
        case IrBinOpCmpGreaterThan:
            return ">";
        case IrBinOpCmpLessOrEq:
            return "<=";
        case IrBinOpCmpGreaterOrEq:
            return ">=";
        case IrBinOpBinOr:
            return "|";
        case IrBinOpBinXor:
            return "^";
        case IrBinOpBinAnd:
            return "&";
        case IrBinOpBitShiftLeftLossy:
            return "<<";
        case IrBinOpBitShiftLeftExact:
            return "@shlExact";
        case IrBinOpBitShiftRightLossy:
            return ">>";
        case IrBinOpBitShiftRightExact:
            return "@shrExact";
        case IrBinOpAdd:
            return "+";
        case IrBinOpAddWrap:
            return "+%";
        case IrBinOpSub:
            return "-";
        case IrBinOpSubWrap:
            return "-%";
        case IrBinOpMult:
            return "*";
        case IrBinOpMultWrap:
            return "*%";
        case IrBinOpDivUnspecified:
            return "/";
        case IrBinOpDivTrunc:
            return "@divTrunc";
        case IrBinOpDivFloor:
            return "@divFloor";
        case IrBinOpDivExact:
            return "@divExact";
        case IrBinOpRemUnspecified:
            return "%";
        case IrBinOpRemRem:
            return "@rem";
        case IrBinOpRemMod:
            return "@mod";
        case IrBinOpArrayCat:
            return "++";
        case IrBinOpArrayMult:
            return "**";
    }
    zig_unreachable();
}

static const char *ir_un_op_id_str(IrUnOp op_id) {
    switch (op_id) {
        case IrUnOpInvalid:
            zig_unreachable();
        case IrUnOpBinNot:
            return "~";
        case IrUnOpNegation:
            return "-";
        case IrUnOpNegationWrap:
            return "-%";
        case IrUnOpDereference:
            return "*";
        case IrUnOpOptional:
            return "?";
    }
    zig_unreachable();
}

static void ir_print_un_op(IrPrint *irp, IrInstructionUnOp *un_op_instruction) {
    fprintf(irp->f, "%s ", ir_un_op_id_str(un_op_instruction->op_id));
    ir_print_other_instruction(irp, un_op_instruction->value);
}

static void ir_print_bin_op(IrPrint *irp, IrInstructionBinOp *bin_op_instruction) {
    ir_print_other_instruction(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_instruction(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_merge_err_sets(IrPrint *irp, IrInstructionMergeErrSets *instruction) {
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, " || ");
    ir_print_other_instruction(irp, instruction->op2);
    if (instruction->type_name != nullptr) {
        fprintf(irp->f, " // name=%s", buf_ptr(instruction->type_name));
    }
}

static void ir_print_decl_var_src(IrPrint *irp, IrInstructionDeclVarSrc *decl_var_instruction) {
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = decl_var_instruction->var->name;
    if (decl_var_instruction->var_type) {
        fprintf(irp->f, "%s %s: ", var_or_const, name);
        ir_print_other_instruction(irp, decl_var_instruction->var_type);
        fprintf(irp->f, " ");
    } else {
        fprintf(irp->f, "%s %s ", var_or_const, name);
    }
    if (decl_var_instruction->align_value) {
        fprintf(irp->f, "align ");
        ir_print_other_instruction(irp, decl_var_instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "= ");
    ir_print_other_instruction(irp, decl_var_instruction->ptr);
    if (decl_var_instruction->var->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, decl_var_instruction->var->is_comptime);
    }
}

static void ir_print_cast(IrPrint *irp, IrInstructionCast *cast_instruction) {
    fprintf(irp->f, "cast ");
    ir_print_other_instruction(irp, cast_instruction->value);
    fprintf(irp->f, " to %s", buf_ptr(&cast_instruction->dest_type->name));
}

static void ir_print_result_loc_var(IrPrint *irp, ResultLocVar *result_loc_var) {
    fprintf(irp->f, "var(");
    ir_print_other_instruction(irp, result_loc_var->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_instruction(IrPrint *irp, ResultLocInstruction *result_loc_inst) {
    fprintf(irp->f, "inst(");
    ir_print_other_instruction(irp, result_loc_inst->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_peer(IrPrint *irp, ResultLocPeer *result_loc_peer) {
    fprintf(irp->f, "peer(next=");
    ir_print_other_block(irp, result_loc_peer->next_bb);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_bit_cast(IrPrint *irp, ResultLocBitCast *result_loc_bit_cast) {
    fprintf(irp->f, "bitcast(ty=");
    ir_print_other_instruction(irp, result_loc_bit_cast->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_cast(IrPrint *irp, ResultLocCast *result_loc_cast) {
    fprintf(irp->f, "cast(ty=");
    ir_print_other_instruction(irp, result_loc_cast->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc(IrPrint *irp, ResultLoc *result_loc) {
    switch (result_loc->id) {
        case ResultLocIdInvalid:
            zig_unreachable();
        case ResultLocIdNone:
            fprintf(irp->f, "none");
            return;
        case ResultLocIdReturn:
            fprintf(irp->f, "return");
            return;
        case ResultLocIdVar:
            return ir_print_result_loc_var(irp, (ResultLocVar *)result_loc);
        case ResultLocIdInstruction:
            return ir_print_result_loc_instruction(irp, (ResultLocInstruction *)result_loc);
        case ResultLocIdPeer:
            return ir_print_result_loc_peer(irp, (ResultLocPeer *)result_loc);
        case ResultLocIdBitCast:
            return ir_print_result_loc_bit_cast(irp, (ResultLocBitCast *)result_loc);
        case ResultLocIdCast:
            return ir_print_result_loc_cast(irp, (ResultLocCast *)result_loc);
        case ResultLocIdPeerParent:
            fprintf(irp->f, "peer_parent");
            return;
    }
    zig_unreachable();
}

static void ir_print_call_extra(IrPrint *irp, IrInstructionCallExtra *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_instruction(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_instruction(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=");
    ir_print_other_instruction(irp, instruction->args);
    fprintf(irp->f, ", result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_call_src_args(IrPrint *irp, IrInstructionCallSrcArgs *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_instruction(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_instruction(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=(");
    for (size_t i = 0; i < instruction->args_len; i += 1) {
        IrInstruction *arg = instruction->args_ptr[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, arg);
    }
    fprintf(irp->f, "), result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_call_src(IrPrint *irp, IrInstructionCallSrc *call_instruction) {
    switch (call_instruction->modifier) {
        case CallModifierNone:
            break;
        case CallModifierNoAsync:
            fprintf(irp->f, "noasync ");
            break;
        case CallModifierAsync:
            fprintf(irp->f, "async ");
            break;
        case CallModifierNeverTail:
            fprintf(irp->f, "notail ");
            break;
        case CallModifierNeverInline:
            fprintf(irp->f, "noinline ");
            break;
        case CallModifierAlwaysTail:
            fprintf(irp->f, "tail ");
            break;
        case CallModifierAlwaysInline:
            fprintf(irp->f, "inline ");
            break;
        case CallModifierCompileTime:
            fprintf(irp->f, "comptime ");
            break;
        case CallModifierBuiltin:
            zig_unreachable();
    }
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_instruction(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, call_instruction->result_loc);
}

static void ir_print_call_gen(IrPrint *irp, IrInstructionCallGen *call_instruction) {
    switch (call_instruction->modifier) {
        case CallModifierNone:
            break;
        case CallModifierNoAsync:
            fprintf(irp->f, "noasync ");
            break;
        case CallModifierAsync:
            fprintf(irp->f, "async ");
            break;
        case CallModifierNeverTail:
            fprintf(irp->f, "notail ");
            break;
        case CallModifierNeverInline:
            fprintf(irp->f, "noinline ");
            break;
        case CallModifierAlwaysTail:
            fprintf(irp->f, "tail ");
            break;
        case CallModifierAlwaysInline:
            fprintf(irp->f, "inline ");
            break;
        case CallModifierCompileTime:
            fprintf(irp->f, "comptime ");
            break;
        case CallModifierBuiltin:
            zig_unreachable();
    }
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_instruction(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, call_instruction->result_loc);
}

static void ir_print_cond_br(IrPrint *irp, IrInstructionCondBr *cond_br_instruction) {
    fprintf(irp->f, "if (");
    ir_print_other_instruction(irp, cond_br_instruction->condition);
    fprintf(irp->f, ") ");
    ir_print_other_block(irp, cond_br_instruction->then_block);
    fprintf(irp->f, " else ");
    ir_print_other_block(irp, cond_br_instruction->else_block);
    if (cond_br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, cond_br_instruction->is_comptime);
    }
}

static void ir_print_br(IrPrint *irp, IrInstructionBr *br_instruction) {
    fprintf(irp->f, "goto ");
    ir_print_other_block(irp, br_instruction->dest_block);
    if (br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, br_instruction->is_comptime);
    }
}

static void ir_print_phi(IrPrint *irp, IrInstructionPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlock *incoming_block = phi_instruction->incoming_blocks[i];
        IrInstruction *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_instruction(irp, incoming_value);
    }
}

static void ir_print_container_init_list(IrPrint *irp, IrInstructionContainerInitList *instruction) {
    fprintf(irp->f, "{");
    if (instruction->item_count > 50) {
        fprintf(irp->f, "...(%" ZIG_PRI_usize " items)...", instruction->item_count);
    } else {
        for (size_t i = 0; i < instruction->item_count; i += 1) {
            IrInstruction *result_loc = instruction->elem_result_loc_list[i];
            if (i != 0)
                fprintf(irp->f, ", ");
            ir_print_other_instruction(irp, result_loc);
        }
    }
    fprintf(irp->f, "}result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_container_init_fields(IrPrint *irp, IrInstructionContainerInitFields *instruction) {
    fprintf(irp->f, "{");
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstructionContainerInitFieldsField *field = &instruction->fields[i];
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(field->name));
        ir_print_other_instruction(irp, field->result_loc);
    }
    fprintf(irp->f, "}result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_unreachable(IrPrint *irp, IrInstructionUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_elem_ptr(IrPrint *irp, IrInstructionElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_instruction(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_var_ptr(IrPrint *irp, IrInstructionVarPtr *instruction) {
    fprintf(irp->f, "&%s", instruction->var->name);
}

static void ir_print_return_ptr(IrPrint *irp, IrInstructionReturnPtr *instruction) {
    fprintf(irp->f, "@ReturnPtr");
}

static void ir_print_load_ptr(IrPrint *irp, IrInstructionLoadPtr *instruction) {
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ".*");
}

static void ir_print_load_ptr_gen(IrPrint *irp, IrInstructionLoadPtrGen *instruction) {
    fprintf(irp->f, "loadptr(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_store_ptr(IrPrint *irp, IrInstructionStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_instruction(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_vector_store_elem(IrPrint *irp, IrInstructionVectorStoreElem *instruction) {
    fprintf(irp->f, "vector_ptr=");
    ir_print_var_instruction(irp, instruction->vector_ptr);
    fprintf(irp->f, ",index=");
    ir_print_var_instruction(irp, instruction->index);
    fprintf(irp->f, ",value=");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_typeof(IrPrint *irp, IrInstructionTypeOf *instruction) {
    fprintf(irp->f, "@TypeOf(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_field_ptr(IrPrint *irp, IrInstructionFieldPtr *instruction) {
    if (instruction->field_name_buffer) {
        fprintf(irp->f, "fieldptr ");
        ir_print_other_instruction(irp, instruction->container_ptr);
        fprintf(irp->f, ".%s", buf_ptr(instruction->field_name_buffer));
    } else {
        assert(instruction->field_name_expr);
        fprintf(irp->f, "@field(");
        ir_print_other_instruction(irp, instruction->container_ptr);
        fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, instruction->field_name_expr);
        fprintf(irp->f, ")");
    }
}

static void ir_print_struct_field_ptr(IrPrint *irp, IrInstructionStructFieldPtr *instruction) {
    fprintf(irp->f, "@StructFieldPtr(&");
    ir_print_other_instruction(irp, instruction->struct_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_union_field_ptr(IrPrint *irp, IrInstructionUnionFieldPtr *instruction) {
    fprintf(irp->f, "@UnionFieldPtr(&");
    ir_print_other_instruction(irp, instruction->union_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->enum_field->name));
    fprintf(irp->f, ")");
}

static void ir_print_set_cold(IrPrint *irp, IrInstructionSetCold *instruction) {
    fprintf(irp->f, "@setCold(");
    ir_print_other_instruction(irp, instruction->is_cold);
    fprintf(irp->f, ")");
}

static void ir_print_set_runtime_safety(IrPrint *irp, IrInstructionSetRuntimeSafety *instruction) {
    fprintf(irp->f, "@setRuntimeSafety(");
    ir_print_other_instruction(irp, instruction->safety_on);
    fprintf(irp->f, ")");
}

static void ir_print_set_float_mode(IrPrint *irp, IrInstructionSetFloatMode *instruction) {
    fprintf(irp->f, "@setFloatMode(");
    ir_print_other_instruction(irp, instruction->scope_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->mode_value);
    fprintf(irp->f, ")");
}

static void ir_print_array_type(IrPrint *irp, IrInstructionArrayType *instruction) {
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->size);
    fprintf(irp->f, "]");
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_slice_type(IrPrint *irp, IrInstructionSliceType *instruction) {
    const char *const_kw = instruction->is_const ? "const " : "";
    fprintf(irp->f, "[]%s", const_kw);
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_any_frame_type(IrPrint *irp, IrInstructionAnyFrameType *instruction) {
    if (instruction->payload_type == nullptr) {
        fprintf(irp->f, "anyframe");
    } else {
        fprintf(irp->f, "anyframe->");
        ir_print_other_instruction(irp, instruction->payload_type);
    }
}

static void ir_print_asm_src(IrPrint *irp, IrInstructionAsmSrc *instruction) {
    assert(instruction->base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.source_node->data.asm_expr;
    const char *volatile_kw = instruction->has_side_effects ? " volatile" : "";
    fprintf(irp->f, "asm%s (", volatile_kw);
    ir_print_other_instruction(irp, instruction->asm_template);

    for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");

        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_output->asm_symbolic_name),
                buf_ptr(asm_output->constraint));
        if (asm_output->return_type) {
            fprintf(irp->f, "-> ");
            ir_print_other_instruction(irp, instruction->output_types[i]);
        } else {
            fprintf(irp->f, "%s", buf_ptr(asm_output->variable_name));
        }
        fprintf(irp->f, ")");
    }

    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->input_list.length; i += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);

        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_input->asm_symbolic_name),
                buf_ptr(asm_input->constraint));
        ir_print_other_instruction(irp, instruction->input_list[i]);
        fprintf(irp->f, ")");
    }
    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->clobber_list.length; i += 1) {
        Buf *reg_name = asm_expr->clobber_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "\"%s\"", buf_ptr(reg_name));
    }
    fprintf(irp->f, ")");
}

static void ir_print_asm_gen(IrPrint *irp, IrInstructionAsmGen *instruction) {
    assert(instruction->base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.source_node->data.asm_expr;
    const char *volatile_kw = instruction->has_side_effects ? " volatile" : "";
    fprintf(irp->f, "asm%s (\"%s\") : ", volatile_kw, buf_ptr(instruction->asm_template));

    for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");

        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_output->asm_symbolic_name),
                buf_ptr(asm_output->constraint));
        if (asm_output->return_type) {
            fprintf(irp->f, "-> ");
            ir_print_other_instruction(irp, instruction->output_types[i]);
        } else {
            fprintf(irp->f, "%s", buf_ptr(asm_output->variable_name));
        }
        fprintf(irp->f, ")");
    }

    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->input_list.length; i += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);

        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_input->asm_symbolic_name),
                buf_ptr(asm_input->constraint));
        ir_print_other_instruction(irp, instruction->input_list[i]);
        fprintf(irp->f, ")");
    }
    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->clobber_list.length; i += 1) {
        Buf *reg_name = asm_expr->clobber_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "\"%s\"", buf_ptr(reg_name));
    }
    fprintf(irp->f, ")");
}

static void ir_print_size_of(IrPrint *irp, IrInstructionSizeOf *instruction) {
    fprintf(irp->f, "@sizeOf(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_test_non_null(IrPrint *irp, IrInstructionTestNonNull *instruction) {
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_optional_unwrap_ptr(IrPrint *irp, IrInstructionOptionalUnwrapPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_instruction(irp, instruction->base_ptr);
    fprintf(irp->f, ".*.?");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_clz(IrPrint *irp, IrInstructionClz *instruction) {
    fprintf(irp->f, "@clz(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrint *irp, IrInstructionCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_pop_count(IrPrint *irp, IrInstructionPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bswap(IrPrint *irp, IrInstructionBswap *instruction) {
    fprintf(irp->f, "@byteSwap(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bit_reverse(IrPrint *irp, IrInstructionBitReverse *instruction) {
    fprintf(irp->f, "@bitReverse(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_switch_br(IrPrint *irp, IrInstructionSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_instruction(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstructionSwitchBrCase *this_case = &instruction->cases[i];
        ir_print_other_instruction(irp, this_case->value);
        fprintf(irp->f, " => ");
        ir_print_other_block(irp, this_case->block);
        fprintf(irp->f, ", ");
    }
    fprintf(irp->f, "else => ");
    ir_print_other_block(irp, instruction->else_block);
    if (instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, instruction->is_comptime);
    }
}

static void ir_print_switch_var(IrPrint *irp, IrInstructionSwitchVar *instruction) {
    fprintf(irp->f, "switchvar ");
    ir_print_other_instruction(irp, instruction->target_value_ptr);
    for (size_t i = 0; i < instruction->prongs_len; i += 1) {
        fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, instruction->prongs_ptr[i]);
    }
}

static void ir_print_switch_else_var(IrPrint *irp, IrInstructionSwitchElseVar *instruction) {
    fprintf(irp->f, "switchelsevar ");
    ir_print_other_instruction(irp, &instruction->switch_br->base);
}

static void ir_print_switch_target(IrPrint *irp, IrInstructionSwitchTarget *instruction) {
    fprintf(irp->f, "switchtarget ");
    ir_print_other_instruction(irp, instruction->target_value_ptr);
}

static void ir_print_union_tag(IrPrint *irp, IrInstructionUnionTag *instruction) {
    fprintf(irp->f, "uniontag ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_import(IrPrint *irp, IrInstructionImport *instruction) {
    fprintf(irp->f, "@import(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_ref(IrPrint *irp, IrInstructionRef *instruction) {
    const char *const_str = instruction->is_const ? "const " : "";
    const char *volatile_str = instruction->is_volatile ? "volatile " : "";
    fprintf(irp->f, "%s%sref ", const_str, volatile_str);
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_ref_gen(IrPrint *irp, IrInstructionRefGen *instruction) {
    fprintf(irp->f, "@ref(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_compile_err(IrPrint *irp, IrInstructionCompileErr *instruction) {
    fprintf(irp->f, "@compileError(");
    ir_print_other_instruction(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_compile_log(IrPrint *irp, IrInstructionCompileLog *instruction) {
    fprintf(irp->f, "@compileLog(");
    for (size_t i = 0; i < instruction->msg_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        IrInstruction *msg = instruction->msg_list[i];
        ir_print_other_instruction(irp, msg);
    }
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrint *irp, IrInstructionErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_import(IrPrint *irp, IrInstructionCImport *instruction) {
    fprintf(irp->f, "@cImport(...)");
}

static void ir_print_c_include(IrPrint *irp, IrInstructionCInclude *instruction) {
    fprintf(irp->f, "@cInclude(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_c_define(IrPrint *irp, IrInstructionCDefine *instruction) {
    fprintf(irp->f, "@cDefine(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_undef(IrPrint *irp, IrInstructionCUndef *instruction) {
    fprintf(irp->f, "@cUndef(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_embed_file(IrPrint *irp, IrInstructionEmbedFile *instruction) {
    fprintf(irp->f, "@embedFile(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_cmpxchg_src(IrPrint *irp, IrInstructionCmpxchgSrc *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->new_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->success_order_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->failure_order_value);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_cmpxchg_gen(IrPrint *irp, IrInstructionCmpxchgGen *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->new_value);
    fprintf(irp->f, ", TODO print atomic orders)result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_fence(IrPrint *irp, IrInstructionFence *instruction) {
    fprintf(irp->f, "@fence(");
    ir_print_other_instruction(irp, instruction->order_value);
    fprintf(irp->f, ")");
}

static void ir_print_truncate(IrPrint *irp, IrInstructionTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_cast(IrPrint *irp, IrInstructionIntCast *instruction) {
    fprintf(irp->f, "@intCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_cast(IrPrint *irp, IrInstructionFloatCast *instruction) {
    fprintf(irp->f, "@floatCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_err_set_cast(IrPrint *irp, IrInstructionErrSetCast *instruction) {
    fprintf(irp->f, "@errSetCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_from_bytes(IrPrint *irp, IrInstructionFromBytes *instruction) {
    fprintf(irp->f, "@bytesToSlice(");
    ir_print_other_instruction(irp, instruction->dest_child_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_to_bytes(IrPrint *irp, IrInstructionToBytes *instruction) {
    fprintf(irp->f, "@sliceToBytes(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_float(IrPrint *irp, IrInstructionIntToFloat *instruction) {
    fprintf(irp->f, "@intToFloat(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_to_int(IrPrint *irp, IrInstructionFloatToInt *instruction) {
    fprintf(irp->f, "@floatToInt(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_bool_to_int(IrPrint *irp, IrInstructionBoolToInt *instruction) {
    fprintf(irp->f, "@boolToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_type(IrPrint *irp, IrInstructionIntType *instruction) {
    fprintf(irp->f, "@IntType(");
    ir_print_other_instruction(irp, instruction->is_signed);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->bit_count);
    fprintf(irp->f, ")");
}

static void ir_print_vector_type(IrPrint *irp, IrInstructionVectorType *instruction) {
    fprintf(irp->f, "@Vector(");
    ir_print_other_instruction(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->elem_type);
    fprintf(irp->f, ")");
}

static void ir_print_shuffle_vector(IrPrint *irp, IrInstructionShuffleVector *instruction) {
    fprintf(irp->f, "@shuffle(");
    ir_print_other_instruction(irp, instruction->scalar_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->a);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->b);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->mask);
    fprintf(irp->f, ")");
}

static void ir_print_splat_src(IrPrint *irp, IrInstructionSplatSrc *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_instruction(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_splat_gen(IrPrint *irp, IrInstructionSplatGen *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_instruction(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_bool_not(IrPrint *irp, IrInstructionBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_memset(IrPrint *irp, IrInstructionMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_instruction(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrint *irp, IrInstructionMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_instruction(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_slice_src(IrPrint *irp, IrInstructionSliceSrc *instruction) {
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_instruction(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_slice_gen(IrPrint *irp, IrInstructionSliceGen *instruction) {
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_instruction(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_member_count(IrPrint *irp, IrInstructionMemberCount *instruction) {
    fprintf(irp->f, "@memberCount(");
    ir_print_other_instruction(irp, instruction->container);
    fprintf(irp->f, ")");
}

static void ir_print_member_type(IrPrint *irp, IrInstructionMemberType *instruction) {
    fprintf(irp->f, "@memberType(");
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->member_index);
    fprintf(irp->f, ")");
}

static void ir_print_member_name(IrPrint *irp, IrInstructionMemberName *instruction) {
    fprintf(irp->f, "@memberName(");
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->member_index);
    fprintf(irp->f, ")");
}

static void ir_print_breakpoint(IrPrint *irp, IrInstructionBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_frame_address(IrPrint *irp, IrInstructionFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_handle(IrPrint *irp, IrInstructionFrameHandle *instruction) {
    fprintf(irp->f, "@frame()");
}

static void ir_print_frame_type(IrPrint *irp, IrInstructionFrameType *instruction) {
    fprintf(irp->f, "@Frame(");
    ir_print_other_instruction(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_src(IrPrint *irp, IrInstructionFrameSizeSrc *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_instruction(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_gen(IrPrint *irp, IrInstructionFrameSizeGen *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_instruction(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_return_address(IrPrint *irp, IrInstructionReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_align_of(IrPrint *irp, IrInstructionAlignOf *instruction) {
    fprintf(irp->f, "@alignOf(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_overflow_op(IrPrint *irp, IrInstructionOverflowOp *instruction) {
    switch (instruction->op) {
        case IrOverflowOpAdd:
            fprintf(irp->f, "@addWithOverflow(");
            break;
        case IrOverflowOpSub:
            fprintf(irp->f, "@subWithOverflow(");
            break;
        case IrOverflowOpMul:
            fprintf(irp->f, "@mulWithOverflow(");
            break;
        case IrOverflowOpShl:
            fprintf(irp->f, "@shlWithOverflow(");
            break;
    }
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->op2);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->result_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err_src(IrPrint *irp, IrInstructionTestErrSrc *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_instruction(irp, instruction->base_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err_gen(IrPrint *irp, IrInstructionTestErrGen *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_instruction(irp, instruction->err_union);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrint *irp, IrInstructionUnwrapErrCode *instruction) {
    fprintf(irp->f, "UnwrapErrorCode(");
    ir_print_other_instruction(irp, instruction->err_union_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_payload(IrPrint *irp, IrInstructionUnwrapErrPayload *instruction) {
    fprintf(irp->f, "ErrorUnionFieldPayload(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")safety=%d,init=%d",instruction->safety_check_on, instruction->initializing);
}

static void ir_print_optional_wrap(IrPrint *irp, IrInstructionOptionalWrap *instruction) {
    fprintf(irp->f, "@optionalWrap(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_err_wrap_code(IrPrint *irp, IrInstructionErrWrapCode *instruction) {
    fprintf(irp->f, "@errWrapCode(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_err_wrap_payload(IrPrint *irp, IrInstructionErrWrapPayload *instruction) {
    fprintf(irp->f, "@errWrapPayload(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_fn_proto(IrPrint *irp, IrInstructionFnProto *instruction) {
    fprintf(irp->f, "fn(");
    for (size_t i = 0; i < instruction->base.source_node->data.fn_proto.params.length; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        if (instruction->is_var_args && i == instruction->base.source_node->data.fn_proto.params.length - 1) {
            fprintf(irp->f, "...");
        } else {
            ir_print_other_instruction(irp, instruction->param_types[i]);
        }
    }
    fprintf(irp->f, ")");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, " align ");
        ir_print_other_instruction(irp, instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "->");
    ir_print_other_instruction(irp, instruction->return_type);
}

static void ir_print_test_comptime(IrPrint *irp, IrInstructionTestComptime *instruction) {
    fprintf(irp->f, "@testComptime(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_src(IrPrint *irp, IrInstructionPtrCastSrc *instruction) {
    fprintf(irp->f, "@ptrCast(");
    if (instruction->dest_type) {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_gen(IrPrint *irp, IrInstructionPtrCastGen *instruction) {
    fprintf(irp->f, "@ptrCast(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_implicit_cast(IrPrint *irp, IrInstructionImplicitCast *instruction) {
    fprintf(irp->f, "@implicitCast(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_cast->base);
}

static void ir_print_bit_cast_src(IrPrint *irp, IrInstructionBitCastSrc *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_bit_cast->base);
}

static void ir_print_bit_cast_gen(IrPrint *irp, IrInstructionBitCastGen *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_widen_or_shorten(IrPrint *irp, IrInstructionWidenOrShorten *instruction) {
    fprintf(irp->f, "WidenOrShorten(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrint *irp, IrInstructionPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrint *irp, IrInstructionIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    if (instruction->dest_type == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrint *irp, IrInstructionIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    if (instruction->dest_type == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_enum_to_int(IrPrint *irp, IrInstructionEnumToInt *instruction) {
    fprintf(irp->f, "@enumToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_check_runtime_scope(IrPrint *irp, IrInstructionCheckRuntimeScope *instruction) {
    fprintf(irp->f, "@checkRuntimeScope(");
    ir_print_other_instruction(irp, instruction->scope_is_comptime);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->is_comptime);
    fprintf(irp->f, ")");
}

static void ir_print_array_to_vector(IrPrint *irp, IrInstructionArrayToVector *instruction) {
    fprintf(irp->f, "ArrayToVector(");
    ir_print_other_instruction(irp, instruction->array);
    fprintf(irp->f, ")");
}

static void ir_print_vector_to_array(IrPrint *irp, IrInstructionVectorToArray *instruction) {
    fprintf(irp->f, "VectorToArray(");
    ir_print_other_instruction(irp, instruction->vector);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_ptr_of_array_to_slice(IrPrint *irp, IrInstructionPtrOfArrayToSlice *instruction) {
    fprintf(irp->f, "PtrOfArrayToSlice(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_assert_zero(IrPrint *irp, IrInstructionAssertZero *instruction) {
    fprintf(irp->f, "AssertZero(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_assert_non_null(IrPrint *irp, IrInstructionAssertNonNull *instruction) {
    fprintf(irp->f, "AssertNonNull(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_resize_slice(IrPrint *irp, IrInstructionResizeSlice *instruction) {
    fprintf(irp->f, "@resizeSlice(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_instruction(irp, instruction->result_loc);
}

static void ir_print_alloca_src(IrPrint *irp, IrInstructionAllocaSrc *instruction) {
    fprintf(irp->f, "Alloca(align=");
    ir_print_other_instruction(irp, instruction->align);
    fprintf(irp->f, ",name=%s)", instruction->name_hint);
}

static void ir_print_alloca_gen(IrPrint *irp, IrInstructionAllocaGen *instruction) {
    fprintf(irp->f, "Alloca(align=%" PRIu32 ",name=%s)", instruction->align, instruction->name_hint);
}

static void ir_print_end_expr(IrPrint *irp, IrInstructionEndExpr *instruction) {
    fprintf(irp->f, "EndExpr(result=");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ",value=");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_err(IrPrint *irp, IrInstructionIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrint *irp, IrInstructionErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_check_switch_prongs(IrPrint *irp, IrInstructionCheckSwitchProngs *instruction) {
    fprintf(irp->f, "@checkSwitchProngs(");
    ir_print_other_instruction(irp, instruction->target_value);
    fprintf(irp->f, ",");
    for (size_t i = 0; i < instruction->range_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->ranges[i].start);
        fprintf(irp->f, "...");
        ir_print_other_instruction(irp, instruction->ranges[i].end);
    }
    const char *have_else_str = instruction->have_else_prong ? "yes" : "no";
    fprintf(irp->f, ")else:%s", have_else_str);
}

static void ir_print_check_statement_is_void(IrPrint *irp, IrInstructionCheckStatementIsVoid *instruction) {
    fprintf(irp->f, "@checkStatementIsVoid(");
    ir_print_other_instruction(irp, instruction->statement_value);
    fprintf(irp->f, ")");
}

static void ir_print_type_name(IrPrint *irp, IrInstructionTypeName *instruction) {
    fprintf(irp->f, "typename ");
    ir_print_other_instruction(irp, instruction->type_value);
}

static void ir_print_tag_name(IrPrint *irp, IrInstructionTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_ptr_type(IrPrint *irp, IrInstructionPtrType *instruction) {
    fprintf(irp->f, "&");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, "align(");
        ir_print_other_instruction(irp, instruction->align_value);
        fprintf(irp->f, ")");
    }
    const char *const_str = instruction->is_const ? "const " : "";
    const char *volatile_str = instruction->is_volatile ? "volatile " : "";
    fprintf(irp->f, ":%" PRIu32 ":%" PRIu32 " %s%s", instruction->bit_offset_start, instruction->host_int_bytes,
            const_str, volatile_str);
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_decl_ref(IrPrint *irp, IrInstructionDeclRef *instruction) {
    const char *ptr_str = (instruction->lval == LValPtr) ? "ptr " : "";
    fprintf(irp->f, "declref %s%s", ptr_str, buf_ptr(instruction->tld->name));
}

static void ir_print_panic(IrPrint *irp, IrInstructionPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_instruction(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrint *irp, IrInstructionFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_byte_offset_of(IrPrint *irp, IrInstructionByteOffsetOf *instruction) {
    fprintf(irp->f, "@byte_offset_of(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_bit_offset_of(IrPrint *irp, IrInstructionBitOffsetOf *instruction) {
    fprintf(irp->f, "@bit_offset_of(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_type_info(IrPrint *irp, IrInstructionTypeInfo *instruction) {
    fprintf(irp->f, "@typeInfo(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_type(IrPrint *irp, IrInstructionType *instruction) {
    fprintf(irp->f, "@Type(");
    ir_print_other_instruction(irp, instruction->type_info);
    fprintf(irp->f, ")");
}

static void ir_print_has_field(IrPrint *irp, IrInstructionHasField *instruction) {
    fprintf(irp->f, "@hasField(");
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_type_id(IrPrint *irp, IrInstructionTypeId *instruction) {
    fprintf(irp->f, "@typeId(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_set_eval_branch_quota(IrPrint *irp, IrInstructionSetEvalBranchQuota *instruction) {
    fprintf(irp->f, "@setEvalBranchQuota(");
    ir_print_other_instruction(irp, instruction->new_quota);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrint *irp, IrInstructionAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    if (instruction->align_bytes == nullptr) {
        fprintf(irp->f, "null");
    } else {
        ir_print_other_instruction(irp, instruction->align_bytes);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_resolve_result(IrPrint *irp, IrInstructionResolveResult *instruction) {
    fprintf(irp->f, "ResolveResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_reset_result(IrPrint *irp, IrInstructionResetResult *instruction) {
    fprintf(irp->f, "ResetResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_opaque_type(IrPrint *irp, IrInstructionOpaqueType *instruction) {
    fprintf(irp->f, "@OpaqueType()");
}

static void ir_print_set_align_stack(IrPrint *irp, IrInstructionSetAlignStack *instruction) {
    fprintf(irp->f, "@setAlignStack(");
    ir_print_other_instruction(irp, instruction->align_bytes);
    fprintf(irp->f, ")");
}

static void ir_print_arg_type(IrPrint *irp, IrInstructionArgType *instruction) {
    fprintf(irp->f, "@ArgType(");
    ir_print_other_instruction(irp, instruction->fn_type);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->arg_index);
    fprintf(irp->f, ")");
}

static void ir_print_enum_tag_type(IrPrint *irp, IrInstructionTagType *instruction) {
    fprintf(irp->f, "@TagType(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_export(IrPrint *irp, IrInstructionExport *instruction) {
    if (instruction->linkage == nullptr) {
        fprintf(irp->f, "@export(");
        ir_print_other_instruction(irp, instruction->name);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->target);
        fprintf(irp->f, ")");
    } else {
        fprintf(irp->f, "@exportWithLinkage(");
        ir_print_other_instruction(irp, instruction->name);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->target);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->linkage);
        fprintf(irp->f, ")");
    }
}

static void ir_print_error_return_trace(IrPrint *irp, IrInstructionErrorReturnTrace *instruction) {
    fprintf(irp->f, "@errorReturnTrace(");
    switch (instruction->optional) {
        case IrInstructionErrorReturnTrace::Null:
            fprintf(irp->f, "Null");
            break;
        case IrInstructionErrorReturnTrace::NonNull:
            fprintf(irp->f, "NonNull");
            break;
    }
    fprintf(irp->f, ")");
}

static void ir_print_error_union(IrPrint *irp, IrInstructionErrorUnion *instruction) {
    ir_print_other_instruction(irp, instruction->err_set);
    fprintf(irp->f, "!");
    ir_print_other_instruction(irp, instruction->payload);
}

static void ir_print_atomic_rmw(IrPrint *irp, IrInstructionAtomicRmw *instruction) {
    fprintf(irp->f, "@atomicRmw(");
    if (instruction->operand_type != nullptr) {
        ir_print_other_instruction(irp, instruction->operand_type);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ",");
    if (instruction->op != nullptr) {
        ir_print_other_instruction(irp, instruction->op);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ",");
    if (instruction->ordering != nullptr) {
        ir_print_other_instruction(irp, instruction->ordering);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ")");
}

static void ir_print_atomic_load(IrPrint *irp, IrInstructionAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    if (instruction->operand_type != nullptr) {
        ir_print_other_instruction(irp, instruction->operand_type);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ",");
    if (instruction->ordering != nullptr) {
        ir_print_other_instruction(irp, instruction->ordering);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ")");
}

static void ir_print_atomic_store(IrPrint *irp, IrInstructionAtomicStore *instruction) {
    fprintf(irp->f, "@atomicStore(");
    if (instruction->operand_type != nullptr) {
        ir_print_other_instruction(irp, instruction->operand_type);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ",");
    if (instruction->ordering != nullptr) {
        ir_print_other_instruction(irp, instruction->ordering);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ")");
}


static void ir_print_save_err_ret_addr(IrPrint *irp, IrInstructionSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_add_implicit_return_type(IrPrint *irp, IrInstructionAddImplicitReturnType *instruction) {
    fprintf(irp->f, "@addImplicitReturnType(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_float_op(IrPrint *irp, IrInstructionFloatOp *instruction) {

    fprintf(irp->f, "@%s(", float_op_to_name(instruction->op, false));
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, ")");
}

static void ir_print_mul_add(IrPrint *irp, IrInstructionMulAdd *instruction) {
    fprintf(irp->f, "@mulAdd(");
    if (instruction->type_value != nullptr) {
        ir_print_other_instruction(irp, instruction->type_value);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op2);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op3);
    fprintf(irp->f, ")");
}

static void ir_print_decl_var_gen(IrPrint *irp, IrInstructionDeclVarGen *decl_var_instruction) {
    ZigVar *var = decl_var_instruction->var;
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = decl_var_instruction->var->name;
    fprintf(irp->f, "%s %s: %s align(%u) = ", var_or_const, name, buf_ptr(&var->var_type->name),
            var->align_bytes);

    ir_print_other_instruction(irp, decl_var_instruction->var_ptr);
    if (decl_var_instruction->var->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, decl_var_instruction->var->is_comptime);
    }
}

static void ir_print_has_decl(IrPrint *irp, IrInstructionHasDecl *instruction) {
    fprintf(irp->f, "@hasDecl(");
    ir_print_other_instruction(irp, instruction->container);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_undeclared_ident(IrPrint *irp, IrInstructionUndeclaredIdent *instruction) {
    fprintf(irp->f, "@undeclaredIdent(%s)", buf_ptr(instruction->name));
}

static void ir_print_union_init_named_field(IrPrint *irp, IrInstructionUnionInitNamedField *instruction) {
    fprintf(irp->f, "@unionInit(");
    ir_print_other_instruction(irp, instruction->union_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->field_result_loc);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_suspend_begin(IrPrint *irp, IrInstructionSuspendBegin *instruction) {
    fprintf(irp->f, "@suspendBegin()");
}

static void ir_print_suspend_finish(IrPrint *irp, IrInstructionSuspendFinish *instruction) {
    fprintf(irp->f, "@suspendFinish()");
}

static void ir_print_resume(IrPrint *irp, IrInstructionResume *instruction) {
    fprintf(irp->f, "resume ");
    ir_print_other_instruction(irp, instruction->frame);
}

static void ir_print_await_src(IrPrint *irp, IrInstructionAwaitSrc *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_instruction(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_await_gen(IrPrint *irp, IrInstructionAwaitGen *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_instruction(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_spill_begin(IrPrint *irp, IrInstructionSpillBegin *instruction) {
    fprintf(irp->f, "@spillBegin(");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_spill_end(IrPrint *irp, IrInstructionSpillEnd *instruction) {
    fprintf(irp->f, "@spillEnd(");
    ir_print_other_instruction(irp, &instruction->begin->base);
    fprintf(irp->f, ")");
}

static void ir_print_vector_extract_elem(IrPrint *irp, IrInstructionVectorExtractElem *instruction) {
    fprintf(irp->f, "@vectorExtractElem(");
    ir_print_other_instruction(irp, instruction->vector);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_instruction(IrPrint *irp, IrInstruction *instruction, bool trailing) {
    ir_print_prefix(irp, instruction, trailing);
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdReturn:
            ir_print_return(irp, (IrInstructionReturn *)instruction);
            break;
        case IrInstructionIdConst:
            ir_print_const(irp, (IrInstructionConst *)instruction);
            break;
        case IrInstructionIdBinOp:
            ir_print_bin_op(irp, (IrInstructionBinOp *)instruction);
            break;
        case IrInstructionIdMergeErrSets:
            ir_print_merge_err_sets(irp, (IrInstructionMergeErrSets *)instruction);
            break;
        case IrInstructionIdDeclVarSrc:
            ir_print_decl_var_src(irp, (IrInstructionDeclVarSrc *)instruction);
            break;
        case IrInstructionIdCast:
            ir_print_cast(irp, (IrInstructionCast *)instruction);
            break;
        case IrInstructionIdCallExtra:
            ir_print_call_extra(irp, (IrInstructionCallExtra *)instruction);
            break;
        case IrInstructionIdCallSrc:
            ir_print_call_src(irp, (IrInstructionCallSrc *)instruction);
            break;
        case IrInstructionIdCallSrcArgs:
            ir_print_call_src_args(irp, (IrInstructionCallSrcArgs *)instruction);
            break;
        case IrInstructionIdCallGen:
            ir_print_call_gen(irp, (IrInstructionCallGen *)instruction);
            break;
        case IrInstructionIdUnOp:
            ir_print_un_op(irp, (IrInstructionUnOp *)instruction);
            break;
        case IrInstructionIdCondBr:
            ir_print_cond_br(irp, (IrInstructionCondBr *)instruction);
            break;
        case IrInstructionIdBr:
            ir_print_br(irp, (IrInstructionBr *)instruction);
            break;
        case IrInstructionIdPhi:
            ir_print_phi(irp, (IrInstructionPhi *)instruction);
            break;
        case IrInstructionIdContainerInitList:
            ir_print_container_init_list(irp, (IrInstructionContainerInitList *)instruction);
            break;
        case IrInstructionIdContainerInitFields:
            ir_print_container_init_fields(irp, (IrInstructionContainerInitFields *)instruction);
            break;
        case IrInstructionIdUnreachable:
            ir_print_unreachable(irp, (IrInstructionUnreachable *)instruction);
            break;
        case IrInstructionIdElemPtr:
            ir_print_elem_ptr(irp, (IrInstructionElemPtr *)instruction);
            break;
        case IrInstructionIdVarPtr:
            ir_print_var_ptr(irp, (IrInstructionVarPtr *)instruction);
            break;
        case IrInstructionIdReturnPtr:
            ir_print_return_ptr(irp, (IrInstructionReturnPtr *)instruction);
            break;
        case IrInstructionIdLoadPtr:
            ir_print_load_ptr(irp, (IrInstructionLoadPtr *)instruction);
            break;
        case IrInstructionIdLoadPtrGen:
            ir_print_load_ptr_gen(irp, (IrInstructionLoadPtrGen *)instruction);
            break;
        case IrInstructionIdStorePtr:
            ir_print_store_ptr(irp, (IrInstructionStorePtr *)instruction);
            break;
        case IrInstructionIdVectorStoreElem:
            ir_print_vector_store_elem(irp, (IrInstructionVectorStoreElem *)instruction);
            break;
        case IrInstructionIdTypeOf:
            ir_print_typeof(irp, (IrInstructionTypeOf *)instruction);
            break;
        case IrInstructionIdFieldPtr:
            ir_print_field_ptr(irp, (IrInstructionFieldPtr *)instruction);
            break;
        case IrInstructionIdStructFieldPtr:
            ir_print_struct_field_ptr(irp, (IrInstructionStructFieldPtr *)instruction);
            break;
        case IrInstructionIdUnionFieldPtr:
            ir_print_union_field_ptr(irp, (IrInstructionUnionFieldPtr *)instruction);
            break;
        case IrInstructionIdSetCold:
            ir_print_set_cold(irp, (IrInstructionSetCold *)instruction);
            break;
        case IrInstructionIdSetRuntimeSafety:
            ir_print_set_runtime_safety(irp, (IrInstructionSetRuntimeSafety *)instruction);
            break;
        case IrInstructionIdSetFloatMode:
            ir_print_set_float_mode(irp, (IrInstructionSetFloatMode *)instruction);
            break;
        case IrInstructionIdArrayType:
            ir_print_array_type(irp, (IrInstructionArrayType *)instruction);
            break;
        case IrInstructionIdSliceType:
            ir_print_slice_type(irp, (IrInstructionSliceType *)instruction);
            break;
        case IrInstructionIdAnyFrameType:
            ir_print_any_frame_type(irp, (IrInstructionAnyFrameType *)instruction);
            break;
        case IrInstructionIdAsmSrc:
            ir_print_asm_src(irp, (IrInstructionAsmSrc *)instruction);
            break;
        case IrInstructionIdAsmGen:
            ir_print_asm_gen(irp, (IrInstructionAsmGen *)instruction);
            break;
        case IrInstructionIdSizeOf:
            ir_print_size_of(irp, (IrInstructionSizeOf *)instruction);
            break;
        case IrInstructionIdTestNonNull:
            ir_print_test_non_null(irp, (IrInstructionTestNonNull *)instruction);
            break;
        case IrInstructionIdOptionalUnwrapPtr:
            ir_print_optional_unwrap_ptr(irp, (IrInstructionOptionalUnwrapPtr *)instruction);
            break;
        case IrInstructionIdPopCount:
            ir_print_pop_count(irp, (IrInstructionPopCount *)instruction);
            break;
        case IrInstructionIdClz:
            ir_print_clz(irp, (IrInstructionClz *)instruction);
            break;
        case IrInstructionIdCtz:
            ir_print_ctz(irp, (IrInstructionCtz *)instruction);
            break;
        case IrInstructionIdBswap:
            ir_print_bswap(irp, (IrInstructionBswap *)instruction);
            break;
        case IrInstructionIdBitReverse:
            ir_print_bit_reverse(irp, (IrInstructionBitReverse *)instruction);
            break;
        case IrInstructionIdSwitchBr:
            ir_print_switch_br(irp, (IrInstructionSwitchBr *)instruction);
            break;
        case IrInstructionIdSwitchVar:
            ir_print_switch_var(irp, (IrInstructionSwitchVar *)instruction);
            break;
        case IrInstructionIdSwitchElseVar:
            ir_print_switch_else_var(irp, (IrInstructionSwitchElseVar *)instruction);
            break;
        case IrInstructionIdSwitchTarget:
            ir_print_switch_target(irp, (IrInstructionSwitchTarget *)instruction);
            break;
        case IrInstructionIdUnionTag:
            ir_print_union_tag(irp, (IrInstructionUnionTag *)instruction);
            break;
        case IrInstructionIdImport:
            ir_print_import(irp, (IrInstructionImport *)instruction);
            break;
        case IrInstructionIdRef:
            ir_print_ref(irp, (IrInstructionRef *)instruction);
            break;
        case IrInstructionIdRefGen:
            ir_print_ref_gen(irp, (IrInstructionRefGen *)instruction);
            break;
        case IrInstructionIdCompileErr:
            ir_print_compile_err(irp, (IrInstructionCompileErr *)instruction);
            break;
        case IrInstructionIdCompileLog:
            ir_print_compile_log(irp, (IrInstructionCompileLog *)instruction);
            break;
        case IrInstructionIdErrName:
            ir_print_err_name(irp, (IrInstructionErrName *)instruction);
            break;
        case IrInstructionIdCImport:
            ir_print_c_import(irp, (IrInstructionCImport *)instruction);
            break;
        case IrInstructionIdCInclude:
            ir_print_c_include(irp, (IrInstructionCInclude *)instruction);
            break;
        case IrInstructionIdCDefine:
            ir_print_c_define(irp, (IrInstructionCDefine *)instruction);
            break;
        case IrInstructionIdCUndef:
            ir_print_c_undef(irp, (IrInstructionCUndef *)instruction);
            break;
        case IrInstructionIdEmbedFile:
            ir_print_embed_file(irp, (IrInstructionEmbedFile *)instruction);
            break;
        case IrInstructionIdCmpxchgSrc:
            ir_print_cmpxchg_src(irp, (IrInstructionCmpxchgSrc *)instruction);
            break;
        case IrInstructionIdCmpxchgGen:
            ir_print_cmpxchg_gen(irp, (IrInstructionCmpxchgGen *)instruction);
            break;
        case IrInstructionIdFence:
            ir_print_fence(irp, (IrInstructionFence *)instruction);
            break;
        case IrInstructionIdTruncate:
            ir_print_truncate(irp, (IrInstructionTruncate *)instruction);
            break;
        case IrInstructionIdIntCast:
            ir_print_int_cast(irp, (IrInstructionIntCast *)instruction);
            break;
        case IrInstructionIdFloatCast:
            ir_print_float_cast(irp, (IrInstructionFloatCast *)instruction);
            break;
        case IrInstructionIdErrSetCast:
            ir_print_err_set_cast(irp, (IrInstructionErrSetCast *)instruction);
            break;
        case IrInstructionIdFromBytes:
            ir_print_from_bytes(irp, (IrInstructionFromBytes *)instruction);
            break;
        case IrInstructionIdToBytes:
            ir_print_to_bytes(irp, (IrInstructionToBytes *)instruction);
            break;
        case IrInstructionIdIntToFloat:
            ir_print_int_to_float(irp, (IrInstructionIntToFloat *)instruction);
            break;
        case IrInstructionIdFloatToInt:
            ir_print_float_to_int(irp, (IrInstructionFloatToInt *)instruction);
            break;
        case IrInstructionIdBoolToInt:
            ir_print_bool_to_int(irp, (IrInstructionBoolToInt *)instruction);
            break;
        case IrInstructionIdIntType:
            ir_print_int_type(irp, (IrInstructionIntType *)instruction);
            break;
        case IrInstructionIdVectorType:
            ir_print_vector_type(irp, (IrInstructionVectorType *)instruction);
            break;
        case IrInstructionIdShuffleVector:
            ir_print_shuffle_vector(irp, (IrInstructionShuffleVector *)instruction);
            break;
        case IrInstructionIdSplatSrc:
            ir_print_splat_src(irp, (IrInstructionSplatSrc *)instruction);
            break;
        case IrInstructionIdSplatGen:
            ir_print_splat_gen(irp, (IrInstructionSplatGen *)instruction);
            break;
        case IrInstructionIdBoolNot:
            ir_print_bool_not(irp, (IrInstructionBoolNot *)instruction);
            break;
        case IrInstructionIdMemset:
            ir_print_memset(irp, (IrInstructionMemset *)instruction);
            break;
        case IrInstructionIdMemcpy:
            ir_print_memcpy(irp, (IrInstructionMemcpy *)instruction);
            break;
        case IrInstructionIdSliceSrc:
            ir_print_slice_src(irp, (IrInstructionSliceSrc *)instruction);
            break;
        case IrInstructionIdSliceGen:
            ir_print_slice_gen(irp, (IrInstructionSliceGen *)instruction);
            break;
        case IrInstructionIdMemberCount:
            ir_print_member_count(irp, (IrInstructionMemberCount *)instruction);
            break;
        case IrInstructionIdMemberType:
            ir_print_member_type(irp, (IrInstructionMemberType *)instruction);
            break;
        case IrInstructionIdMemberName:
            ir_print_member_name(irp, (IrInstructionMemberName *)instruction);
            break;
        case IrInstructionIdBreakpoint:
            ir_print_breakpoint(irp, (IrInstructionBreakpoint *)instruction);
            break;
        case IrInstructionIdReturnAddress:
            ir_print_return_address(irp, (IrInstructionReturnAddress *)instruction);
            break;
        case IrInstructionIdFrameAddress:
            ir_print_frame_address(irp, (IrInstructionFrameAddress *)instruction);
            break;
        case IrInstructionIdFrameHandle:
            ir_print_handle(irp, (IrInstructionFrameHandle *)instruction);
            break;
        case IrInstructionIdFrameType:
            ir_print_frame_type(irp, (IrInstructionFrameType *)instruction);
            break;
        case IrInstructionIdFrameSizeSrc:
            ir_print_frame_size_src(irp, (IrInstructionFrameSizeSrc *)instruction);
            break;
        case IrInstructionIdFrameSizeGen:
            ir_print_frame_size_gen(irp, (IrInstructionFrameSizeGen *)instruction);
            break;
        case IrInstructionIdAlignOf:
            ir_print_align_of(irp, (IrInstructionAlignOf *)instruction);
            break;
        case IrInstructionIdOverflowOp:
            ir_print_overflow_op(irp, (IrInstructionOverflowOp *)instruction);
            break;
        case IrInstructionIdTestErrSrc:
            ir_print_test_err_src(irp, (IrInstructionTestErrSrc *)instruction);
            break;
        case IrInstructionIdTestErrGen:
            ir_print_test_err_gen(irp, (IrInstructionTestErrGen *)instruction);
            break;
        case IrInstructionIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (IrInstructionUnwrapErrCode *)instruction);
            break;
        case IrInstructionIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (IrInstructionUnwrapErrPayload *)instruction);
            break;
        case IrInstructionIdOptionalWrap:
            ir_print_optional_wrap(irp, (IrInstructionOptionalWrap *)instruction);
            break;
        case IrInstructionIdErrWrapCode:
            ir_print_err_wrap_code(irp, (IrInstructionErrWrapCode *)instruction);
            break;
        case IrInstructionIdErrWrapPayload:
            ir_print_err_wrap_payload(irp, (IrInstructionErrWrapPayload *)instruction);
            break;
        case IrInstructionIdFnProto:
            ir_print_fn_proto(irp, (IrInstructionFnProto *)instruction);
            break;
        case IrInstructionIdTestComptime:
            ir_print_test_comptime(irp, (IrInstructionTestComptime *)instruction);
            break;
        case IrInstructionIdPtrCastSrc:
            ir_print_ptr_cast_src(irp, (IrInstructionPtrCastSrc *)instruction);
            break;
        case IrInstructionIdPtrCastGen:
            ir_print_ptr_cast_gen(irp, (IrInstructionPtrCastGen *)instruction);
            break;
        case IrInstructionIdBitCastSrc:
            ir_print_bit_cast_src(irp, (IrInstructionBitCastSrc *)instruction);
            break;
        case IrInstructionIdBitCastGen:
            ir_print_bit_cast_gen(irp, (IrInstructionBitCastGen *)instruction);
            break;
        case IrInstructionIdWidenOrShorten:
            ir_print_widen_or_shorten(irp, (IrInstructionWidenOrShorten *)instruction);
            break;
        case IrInstructionIdPtrToInt:
            ir_print_ptr_to_int(irp, (IrInstructionPtrToInt *)instruction);
            break;
        case IrInstructionIdIntToPtr:
            ir_print_int_to_ptr(irp, (IrInstructionIntToPtr *)instruction);
            break;
        case IrInstructionIdIntToEnum:
            ir_print_int_to_enum(irp, (IrInstructionIntToEnum *)instruction);
            break;
        case IrInstructionIdIntToErr:
            ir_print_int_to_err(irp, (IrInstructionIntToErr *)instruction);
            break;
        case IrInstructionIdErrToInt:
            ir_print_err_to_int(irp, (IrInstructionErrToInt *)instruction);
            break;
        case IrInstructionIdCheckSwitchProngs:
            ir_print_check_switch_prongs(irp, (IrInstructionCheckSwitchProngs *)instruction);
            break;
        case IrInstructionIdCheckStatementIsVoid:
            ir_print_check_statement_is_void(irp, (IrInstructionCheckStatementIsVoid *)instruction);
            break;
        case IrInstructionIdTypeName:
            ir_print_type_name(irp, (IrInstructionTypeName *)instruction);
            break;
        case IrInstructionIdTagName:
            ir_print_tag_name(irp, (IrInstructionTagName *)instruction);
            break;
        case IrInstructionIdPtrType:
            ir_print_ptr_type(irp, (IrInstructionPtrType *)instruction);
            break;
        case IrInstructionIdDeclRef:
            ir_print_decl_ref(irp, (IrInstructionDeclRef *)instruction);
            break;
        case IrInstructionIdPanic:
            ir_print_panic(irp, (IrInstructionPanic *)instruction);
            break;
        case IrInstructionIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (IrInstructionFieldParentPtr *)instruction);
            break;
        case IrInstructionIdByteOffsetOf:
            ir_print_byte_offset_of(irp, (IrInstructionByteOffsetOf *)instruction);
            break;
        case IrInstructionIdBitOffsetOf:
            ir_print_bit_offset_of(irp, (IrInstructionBitOffsetOf *)instruction);
            break;
        case IrInstructionIdTypeInfo:
            ir_print_type_info(irp, (IrInstructionTypeInfo *)instruction);
            break;
        case IrInstructionIdType:
            ir_print_type(irp, (IrInstructionType *)instruction);
            break;
        case IrInstructionIdHasField:
            ir_print_has_field(irp, (IrInstructionHasField *)instruction);
            break;
        case IrInstructionIdTypeId:
            ir_print_type_id(irp, (IrInstructionTypeId *)instruction);
            break;
        case IrInstructionIdSetEvalBranchQuota:
            ir_print_set_eval_branch_quota(irp, (IrInstructionSetEvalBranchQuota *)instruction);
            break;
        case IrInstructionIdAlignCast:
            ir_print_align_cast(irp, (IrInstructionAlignCast *)instruction);
            break;
        case IrInstructionIdImplicitCast:
            ir_print_implicit_cast(irp, (IrInstructionImplicitCast *)instruction);
            break;
        case IrInstructionIdResolveResult:
            ir_print_resolve_result(irp, (IrInstructionResolveResult *)instruction);
            break;
        case IrInstructionIdResetResult:
            ir_print_reset_result(irp, (IrInstructionResetResult *)instruction);
            break;
        case IrInstructionIdOpaqueType:
            ir_print_opaque_type(irp, (IrInstructionOpaqueType *)instruction);
            break;
        case IrInstructionIdSetAlignStack:
            ir_print_set_align_stack(irp, (IrInstructionSetAlignStack *)instruction);
            break;
        case IrInstructionIdArgType:
            ir_print_arg_type(irp, (IrInstructionArgType *)instruction);
            break;
        case IrInstructionIdTagType:
            ir_print_enum_tag_type(irp, (IrInstructionTagType *)instruction);
            break;
        case IrInstructionIdExport:
            ir_print_export(irp, (IrInstructionExport *)instruction);
            break;
        case IrInstructionIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (IrInstructionErrorReturnTrace *)instruction);
            break;
        case IrInstructionIdErrorUnion:
            ir_print_error_union(irp, (IrInstructionErrorUnion *)instruction);
            break;
        case IrInstructionIdAtomicRmw:
            ir_print_atomic_rmw(irp, (IrInstructionAtomicRmw *)instruction);
            break;
        case IrInstructionIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (IrInstructionSaveErrRetAddr *)instruction);
            break;
        case IrInstructionIdAddImplicitReturnType:
            ir_print_add_implicit_return_type(irp, (IrInstructionAddImplicitReturnType *)instruction);
            break;
        case IrInstructionIdFloatOp:
            ir_print_float_op(irp, (IrInstructionFloatOp *)instruction);
            break;
        case IrInstructionIdMulAdd:
            ir_print_mul_add(irp, (IrInstructionMulAdd *)instruction);
            break;
        case IrInstructionIdAtomicLoad:
            ir_print_atomic_load(irp, (IrInstructionAtomicLoad *)instruction);
            break;
        case IrInstructionIdAtomicStore:
            ir_print_atomic_store(irp, (IrInstructionAtomicStore *)instruction);
            break;
        case IrInstructionIdEnumToInt:
            ir_print_enum_to_int(irp, (IrInstructionEnumToInt *)instruction);
            break;
        case IrInstructionIdCheckRuntimeScope:
            ir_print_check_runtime_scope(irp, (IrInstructionCheckRuntimeScope *)instruction);
            break;
        case IrInstructionIdDeclVarGen:
            ir_print_decl_var_gen(irp, (IrInstructionDeclVarGen *)instruction);
            break;
        case IrInstructionIdArrayToVector:
            ir_print_array_to_vector(irp, (IrInstructionArrayToVector *)instruction);
            break;
        case IrInstructionIdVectorToArray:
            ir_print_vector_to_array(irp, (IrInstructionVectorToArray *)instruction);
            break;
        case IrInstructionIdPtrOfArrayToSlice:
            ir_print_ptr_of_array_to_slice(irp, (IrInstructionPtrOfArrayToSlice *)instruction);
            break;
        case IrInstructionIdAssertZero:
            ir_print_assert_zero(irp, (IrInstructionAssertZero *)instruction);
            break;
        case IrInstructionIdAssertNonNull:
            ir_print_assert_non_null(irp, (IrInstructionAssertNonNull *)instruction);
            break;
        case IrInstructionIdResizeSlice:
            ir_print_resize_slice(irp, (IrInstructionResizeSlice *)instruction);
            break;
        case IrInstructionIdHasDecl:
            ir_print_has_decl(irp, (IrInstructionHasDecl *)instruction);
            break;
        case IrInstructionIdUndeclaredIdent:
            ir_print_undeclared_ident(irp, (IrInstructionUndeclaredIdent *)instruction);
            break;
        case IrInstructionIdAllocaSrc:
            ir_print_alloca_src(irp, (IrInstructionAllocaSrc *)instruction);
            break;
        case IrInstructionIdAllocaGen:
            ir_print_alloca_gen(irp, (IrInstructionAllocaGen *)instruction);
            break;
        case IrInstructionIdEndExpr:
            ir_print_end_expr(irp, (IrInstructionEndExpr *)instruction);
            break;
        case IrInstructionIdUnionInitNamedField:
            ir_print_union_init_named_field(irp, (IrInstructionUnionInitNamedField *)instruction);
            break;
        case IrInstructionIdSuspendBegin:
            ir_print_suspend_begin(irp, (IrInstructionSuspendBegin *)instruction);
            break;
        case IrInstructionIdSuspendFinish:
            ir_print_suspend_finish(irp, (IrInstructionSuspendFinish *)instruction);
            break;
        case IrInstructionIdResume:
            ir_print_resume(irp, (IrInstructionResume *)instruction);
            break;
        case IrInstructionIdAwaitSrc:
            ir_print_await_src(irp, (IrInstructionAwaitSrc *)instruction);
            break;
        case IrInstructionIdAwaitGen:
            ir_print_await_gen(irp, (IrInstructionAwaitGen *)instruction);
            break;
        case IrInstructionIdSpillBegin:
            ir_print_spill_begin(irp, (IrInstructionSpillBegin *)instruction);
            break;
        case IrInstructionIdSpillEnd:
            ir_print_spill_end(irp, (IrInstructionSpillEnd *)instruction);
            break;
        case IrInstructionIdVectorExtractElem:
            ir_print_vector_extract_elem(irp, (IrInstructionVectorExtractElem *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

static void irp_print_basic_block(IrPrint *irp, IrBasicBlock *current_block) {
    fprintf(irp->f, "%s_%" ZIG_PRI_usize ":\n", current_block->name_hint, current_block->debug_id);
    for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
        IrInstruction *instruction = current_block->instruction_list.at(instr_i);
        if (irp->pass != IrPassSrc) {
            irp->printed.put(instruction, 0);
            irp->pending.clear();
        }
        ir_print_instruction(irp, instruction, false);
        for (size_t j = 0; j < irp->pending.length; ++j)
            ir_print_instruction(irp, irp->pending.at(j), true);
    }
}

void ir_print_basic_block(CodeGen *codegen, FILE *f, IrBasicBlock *bb, int indent_size, IrPass pass) {
    IrPrint ir_print = {};
    ir_print.pass = pass;
    ir_print.codegen = codegen;
    ir_print.f = f;
    ir_print.indent = indent_size;
    ir_print.indent_size = indent_size;
    ir_print.printed = {};
    ir_print.printed.init(64);
    ir_print.pending = {};

    irp_print_basic_block(&ir_print, bb);

    ir_print.pending.deinit();
    ir_print.printed.deinit();
}

void ir_print(CodeGen *codegen, FILE *f, IrExecutable *executable, int indent_size, IrPass pass) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->pass = pass;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;
    irp->printed = {};
    irp->printed.init(64);
    irp->pending = {};

    for (size_t bb_i = 0; bb_i < executable->basic_block_list.length; bb_i += 1) {
        irp_print_basic_block(irp, executable->basic_block_list.at(bb_i));
    }

    irp->pending.deinit();
    irp->printed.deinit();
}

void ir_print_instruction(CodeGen *codegen, FILE *f, IrInstruction *instruction, int indent_size, IrPass pass) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->pass = pass;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;
    irp->printed = {};
    irp->printed.init(4);
    irp->pending = {};

    ir_print_instruction(irp, instruction, false);
}

void ir_print_const_expr(CodeGen *codegen, FILE *f, ZigValue *value, int indent_size, IrPass pass) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->pass = pass;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;
    irp->printed = {};
    irp->printed.init(4);
    irp->pending = {};

    ir_print_const_value(irp, value);
}
