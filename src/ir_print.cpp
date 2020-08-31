/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "all_types.hpp"
#include "analyze.hpp"
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"

static uint32_t hash_inst_src_ptr(IrInstSrc* instruction) {
    return (uint32_t)(uintptr_t)instruction;
}

static uint32_t hash_inst_gen_ptr(IrInstGen* instruction) {
    return (uint32_t)(uintptr_t)instruction;
}

static bool inst_src_ptr_eql(IrInstSrc* a, IrInstSrc* b) {
    return a == b;
}

static bool inst_gen_ptr_eql(IrInstGen* a, IrInstGen* b) {
    return a == b;
}

using InstSetSrc = HashMap<IrInstSrc*, uint8_t, hash_inst_src_ptr, inst_src_ptr_eql>;
using InstSetGen = HashMap<IrInstGen*, uint8_t, hash_inst_gen_ptr, inst_gen_ptr_eql>;
using InstListSrc = ZigList<IrInstSrc*>;
using InstListGen = ZigList<IrInstGen*>;

struct IrPrintSrc {
    CodeGen *codegen;
    FILE *f;
    int indent;
    int indent_size;
};

struct IrPrintGen {
    CodeGen *codegen;
    FILE *f;
    int indent;
    int indent_size;

    // When printing pass 2 instructions referenced var instructions are not
    // present in the instruction list. Thus we track which instructions
    // are printed (per executable) and after each pass 2 instruction those
    // var instructions are rendered in a trailing fashion.
    InstSetGen printed;
    InstListGen pending;
};

static void ir_print_other_inst_src(IrPrintSrc *irp, IrInstSrc *inst);
static void ir_print_other_inst_gen(IrPrintGen *irp, IrInstGen *inst);

static void ir_print_call_modifier(FILE *f, CallModifier modifier) {
    switch (modifier) {
        case CallModifierNone:
            break;
        case CallModifierNoSuspend:
            fprintf(f, "nosuspend ");
            break;
        case CallModifierAsync:
            fprintf(f, "async ");
            break;
        case CallModifierNeverTail:
            fprintf(f, "notail ");
            break;
        case CallModifierNeverInline:
            fprintf(f, "noinline ");
            break;
        case CallModifierAlwaysTail:
            fprintf(f, "tail ");
            break;
        case CallModifierAlwaysInline:
            fprintf(f, "inline ");
            break;
        case CallModifierCompileTime:
            fprintf(f, "comptime ");
            break;
        case CallModifierBuiltin:
            zig_unreachable();
    }
}

const char* ir_inst_src_type_str(IrInstSrcId id) {
    switch (id) {
        case IrInstSrcIdInvalid:
            return "SrcInvalid";
        case IrInstSrcIdShuffleVector:
            return "SrcShuffle";
        case IrInstSrcIdSplat:
            return "SrcSplat";
        case IrInstSrcIdDeclVar:
            return "SrcDeclVar";
        case IrInstSrcIdBr:
            return "SrcBr";
        case IrInstSrcIdCondBr:
            return "SrcCondBr";
        case IrInstSrcIdSwitchBr:
            return "SrcSwitchBr";
        case IrInstSrcIdSwitchVar:
            return "SrcSwitchVar";
        case IrInstSrcIdSwitchElseVar:
            return "SrcSwitchElseVar";
        case IrInstSrcIdSwitchTarget:
            return "SrcSwitchTarget";
        case IrInstSrcIdPhi:
            return "SrcPhi";
        case IrInstSrcIdUnOp:
            return "SrcUnOp";
        case IrInstSrcIdBinOp:
            return "SrcBinOp";
        case IrInstSrcIdMergeErrSets:
            return "SrcMergeErrSets";
        case IrInstSrcIdLoadPtr:
            return "SrcLoadPtr";
        case IrInstSrcIdStorePtr:
            return "SrcStorePtr";
        case IrInstSrcIdFieldPtr:
            return "SrcFieldPtr";
        case IrInstSrcIdElemPtr:
            return "SrcElemPtr";
        case IrInstSrcIdVarPtr:
            return "SrcVarPtr";
        case IrInstSrcIdCallExtra:
            return "SrcCallExtra";
        case IrInstSrcIdAsyncCallExtra:
            return "SrcAsyncCallExtra";
        case IrInstSrcIdCall:
            return "SrcCall";
        case IrInstSrcIdCallArgs:
            return "SrcCallArgs";
        case IrInstSrcIdConst:
            return "SrcConst";
        case IrInstSrcIdReturn:
            return "SrcReturn";
        case IrInstSrcIdContainerInitList:
            return "SrcContainerInitList";
        case IrInstSrcIdContainerInitFields:
            return "SrcContainerInitFields";
        case IrInstSrcIdUnreachable:
            return "SrcUnreachable";
        case IrInstSrcIdTypeOf:
            return "SrcTypeOf";
        case IrInstSrcIdSetCold:
            return "SrcSetCold";
        case IrInstSrcIdSetRuntimeSafety:
            return "SrcSetRuntimeSafety";
        case IrInstSrcIdSetFloatMode:
            return "SrcSetFloatMode";
        case IrInstSrcIdArrayType:
            return "SrcArrayType";
        case IrInstSrcIdAnyFrameType:
            return "SrcAnyFrameType";
        case IrInstSrcIdSliceType:
            return "SrcSliceType";
        case IrInstSrcIdAsm:
            return "SrcAsm";
        case IrInstSrcIdSizeOf:
            return "SrcSizeOf";
        case IrInstSrcIdTestNonNull:
            return "SrcTestNonNull";
        case IrInstSrcIdOptionalUnwrapPtr:
            return "SrcOptionalUnwrapPtr";
        case IrInstSrcIdClz:
            return "SrcClz";
        case IrInstSrcIdCtz:
            return "SrcCtz";
        case IrInstSrcIdPopCount:
            return "SrcPopCount";
        case IrInstSrcIdBswap:
            return "SrcBswap";
        case IrInstSrcIdBitReverse:
            return "SrcBitReverse";
        case IrInstSrcIdImport:
            return "SrcImport";
        case IrInstSrcIdCImport:
            return "SrcCImport";
        case IrInstSrcIdCInclude:
            return "SrcCInclude";
        case IrInstSrcIdCDefine:
            return "SrcCDefine";
        case IrInstSrcIdCUndef:
            return "SrcCUndef";
        case IrInstSrcIdRef:
            return "SrcRef";
        case IrInstSrcIdCompileErr:
            return "SrcCompileErr";
        case IrInstSrcIdCompileLog:
            return "SrcCompileLog";
        case IrInstSrcIdErrName:
            return "SrcErrName";
        case IrInstSrcIdEmbedFile:
            return "SrcEmbedFile";
        case IrInstSrcIdCmpxchg:
            return "SrcCmpxchg";
        case IrInstSrcIdFence:
            return "SrcFence";
        case IrInstSrcIdTruncate:
            return "SrcTruncate";
        case IrInstSrcIdIntCast:
            return "SrcIntCast";
        case IrInstSrcIdFloatCast:
            return "SrcFloatCast";
        case IrInstSrcIdIntToFloat:
            return "SrcIntToFloat";
        case IrInstSrcIdFloatToInt:
            return "SrcFloatToInt";
        case IrInstSrcIdBoolToInt:
            return "SrcBoolToInt";
        case IrInstSrcIdVectorType:
            return "SrcVectorType";
        case IrInstSrcIdBoolNot:
            return "SrcBoolNot";
        case IrInstSrcIdMemset:
            return "SrcMemset";
        case IrInstSrcIdMemcpy:
            return "SrcMemcpy";
        case IrInstSrcIdSlice:
            return "SrcSlice";
        case IrInstSrcIdBreakpoint:
            return "SrcBreakpoint";
        case IrInstSrcIdReturnAddress:
            return "SrcReturnAddress";
        case IrInstSrcIdFrameAddress:
            return "SrcFrameAddress";
        case IrInstSrcIdFrameHandle:
            return "SrcFrameHandle";
        case IrInstSrcIdFrameType:
            return "SrcFrameType";
        case IrInstSrcIdFrameSize:
            return "SrcFrameSize";
        case IrInstSrcIdAlignOf:
            return "SrcAlignOf";
        case IrInstSrcIdOverflowOp:
            return "SrcOverflowOp";
        case IrInstSrcIdTestErr:
            return "SrcTestErr";
        case IrInstSrcIdMulAdd:
            return "SrcMulAdd";
        case IrInstSrcIdFloatOp:
            return "SrcFloatOp";
        case IrInstSrcIdUnwrapErrCode:
            return "SrcUnwrapErrCode";
        case IrInstSrcIdUnwrapErrPayload:
            return "SrcUnwrapErrPayload";
        case IrInstSrcIdFnProto:
            return "SrcFnProto";
        case IrInstSrcIdTestComptime:
            return "SrcTestComptime";
        case IrInstSrcIdPtrCast:
            return "SrcPtrCast";
        case IrInstSrcIdBitCast:
            return "SrcBitCast";
        case IrInstSrcIdIntToPtr:
            return "SrcIntToPtr";
        case IrInstSrcIdPtrToInt:
            return "SrcPtrToInt";
        case IrInstSrcIdIntToEnum:
            return "SrcIntToEnum";
        case IrInstSrcIdEnumToInt:
            return "SrcEnumToInt";
        case IrInstSrcIdIntToErr:
            return "SrcIntToErr";
        case IrInstSrcIdErrToInt:
            return "SrcErrToInt";
        case IrInstSrcIdCheckSwitchProngs:
            return "SrcCheckSwitchProngs";
        case IrInstSrcIdCheckStatementIsVoid:
            return "SrcCheckStatementIsVoid";
        case IrInstSrcIdTypeName:
            return "SrcTypeName";
        case IrInstSrcIdDeclRef:
            return "SrcDeclRef";
        case IrInstSrcIdPanic:
            return "SrcPanic";
        case IrInstSrcIdTagName:
            return "SrcTagName";
        case IrInstSrcIdTagType:
            return "SrcTagType";
        case IrInstSrcIdFieldParentPtr:
            return "SrcFieldParentPtr";
        case IrInstSrcIdByteOffsetOf:
            return "SrcByteOffsetOf";
        case IrInstSrcIdBitOffsetOf:
            return "SrcBitOffsetOf";
        case IrInstSrcIdTypeInfo:
            return "SrcTypeInfo";
        case IrInstSrcIdType:
            return "SrcType";
        case IrInstSrcIdHasField:
            return "SrcHasField";
        case IrInstSrcIdSetEvalBranchQuota:
            return "SrcSetEvalBranchQuota";
        case IrInstSrcIdPtrType:
            return "SrcPtrType";
        case IrInstSrcIdAlignCast:
            return "SrcAlignCast";
        case IrInstSrcIdImplicitCast:
            return "SrcImplicitCast";
        case IrInstSrcIdResolveResult:
            return "SrcResolveResult";
        case IrInstSrcIdResetResult:
            return "SrcResetResult";
        case IrInstSrcIdSetAlignStack:
            return "SrcSetAlignStack";
        case IrInstSrcIdArgType:
            return "SrcArgType";
        case IrInstSrcIdExport:
            return "SrcExport";
        case IrInstSrcIdErrorReturnTrace:
            return "SrcErrorReturnTrace";
        case IrInstSrcIdErrorUnion:
            return "SrcErrorUnion";
        case IrInstSrcIdAtomicRmw:
            return "SrcAtomicRmw";
        case IrInstSrcIdAtomicLoad:
            return "SrcAtomicLoad";
        case IrInstSrcIdAtomicStore:
            return "SrcAtomicStore";
        case IrInstSrcIdSaveErrRetAddr:
            return "SrcSaveErrRetAddr";
        case IrInstSrcIdAddImplicitReturnType:
            return "SrcAddImplicitReturnType";
        case IrInstSrcIdErrSetCast:
            return "SrcErrSetCast";
        case IrInstSrcIdCheckRuntimeScope:
            return "SrcCheckRuntimeScope";
        case IrInstSrcIdHasDecl:
            return "SrcHasDecl";
        case IrInstSrcIdUndeclaredIdent:
            return "SrcUndeclaredIdent";
        case IrInstSrcIdAlloca:
            return "SrcAlloca";
        case IrInstSrcIdEndExpr:
            return "SrcEndExpr";
        case IrInstSrcIdUnionInitNamedField:
            return "SrcUnionInitNamedField";
        case IrInstSrcIdSuspendBegin:
            return "SrcSuspendBegin";
        case IrInstSrcIdSuspendFinish:
            return "SrcSuspendFinish";
        case IrInstSrcIdAwait:
            return "SrcAwaitSr";
        case IrInstSrcIdResume:
            return "SrcResume";
        case IrInstSrcIdSpillBegin:
            return "SrcSpillBegin";
        case IrInstSrcIdSpillEnd:
            return "SrcSpillEnd";
        case IrInstSrcIdWasmMemorySize:
            return "SrcWasmMemorySize";
        case IrInstSrcIdWasmMemoryGrow:
            return "SrcWasmMemoryGrow";
        case IrInstSrcIdSrc:
            return "SrcSrc";
    }
    zig_unreachable();
}

const char* ir_inst_gen_type_str(IrInstGenId id) {
    switch (id) {
        case IrInstGenIdInvalid:
            return "GenInvalid";
        case IrInstGenIdShuffleVector:
            return "GenShuffle";
        case IrInstGenIdSplat:
            return "GenSplat";
        case IrInstGenIdDeclVar:
            return "GenDeclVar";
        case IrInstGenIdBr:
            return "GenBr";
        case IrInstGenIdCondBr:
            return "GenCondBr";
        case IrInstGenIdSwitchBr:
            return "GenSwitchBr";
        case IrInstGenIdPhi:
            return "GenPhi";
        case IrInstGenIdBinOp:
            return "GenBinOp";
        case IrInstGenIdLoadPtr:
            return "GenLoadPtr";
        case IrInstGenIdStorePtr:
            return "GenStorePtr";
        case IrInstGenIdVectorStoreElem:
            return "GenVectorStoreElem";
        case IrInstGenIdStructFieldPtr:
            return "GenStructFieldPtr";
        case IrInstGenIdUnionFieldPtr:
            return "GenUnionFieldPtr";
        case IrInstGenIdElemPtr:
            return "GenElemPtr";
        case IrInstGenIdVarPtr:
            return "GenVarPtr";
        case IrInstGenIdReturnPtr:
            return "GenReturnPtr";
        case IrInstGenIdCall:
            return "GenCall";
        case IrInstGenIdConst:
            return "GenConst";
        case IrInstGenIdReturn:
            return "GenReturn";
        case IrInstGenIdCast:
            return "GenCast";
        case IrInstGenIdUnreachable:
            return "GenUnreachable";
        case IrInstGenIdAsm:
            return "GenAsm";
        case IrInstGenIdTestNonNull:
            return "GenTestNonNull";
        case IrInstGenIdOptionalUnwrapPtr:
            return "GenOptionalUnwrapPtr";
        case IrInstGenIdOptionalWrap:
            return "GenOptionalWrap";
        case IrInstGenIdUnionTag:
            return "GenUnionTag";
        case IrInstGenIdClz:
            return "GenClz";
        case IrInstGenIdCtz:
            return "GenCtz";
        case IrInstGenIdPopCount:
            return "GenPopCount";
        case IrInstGenIdBswap:
            return "GenBswap";
        case IrInstGenIdBitReverse:
            return "GenBitReverse";
        case IrInstGenIdRef:
            return "GenRef";
        case IrInstGenIdErrName:
            return "GenErrName";
        case IrInstGenIdCmpxchg:
            return "GenCmpxchg";
        case IrInstGenIdFence:
            return "GenFence";
        case IrInstGenIdTruncate:
            return "GenTruncate";
        case IrInstGenIdBoolNot:
            return "GenBoolNot";
        case IrInstGenIdMemset:
            return "GenMemset";
        case IrInstGenIdMemcpy:
            return "GenMemcpy";
        case IrInstGenIdSlice:
            return "GenSlice";
        case IrInstGenIdBreakpoint:
            return "GenBreakpoint";
        case IrInstGenIdReturnAddress:
            return "GenReturnAddress";
        case IrInstGenIdFrameAddress:
            return "GenFrameAddress";
        case IrInstGenIdFrameHandle:
            return "GenFrameHandle";
        case IrInstGenIdFrameSize:
            return "GenFrameSize";
        case IrInstGenIdOverflowOp:
            return "GenOverflowOp";
        case IrInstGenIdTestErr:
            return "GenTestErr";
        case IrInstGenIdMulAdd:
            return "GenMulAdd";
        case IrInstGenIdFloatOp:
            return "GenFloatOp";
        case IrInstGenIdUnwrapErrCode:
            return "GenUnwrapErrCode";
        case IrInstGenIdUnwrapErrPayload:
            return "GenUnwrapErrPayload";
        case IrInstGenIdErrWrapCode:
            return "GenErrWrapCode";
        case IrInstGenIdErrWrapPayload:
            return "GenErrWrapPayload";
        case IrInstGenIdPtrCast:
            return "GenPtrCast";
        case IrInstGenIdBitCast:
            return "GenBitCast";
        case IrInstGenIdWidenOrShorten:
            return "GenWidenOrShorten";
        case IrInstGenIdIntToPtr:
            return "GenIntToPtr";
        case IrInstGenIdPtrToInt:
            return "GenPtrToInt";
        case IrInstGenIdIntToEnum:
            return "GenIntToEnum";
        case IrInstGenIdIntToErr:
            return "GenIntToErr";
        case IrInstGenIdErrToInt:
            return "GenErrToInt";
        case IrInstGenIdPanic:
            return "GenPanic";
        case IrInstGenIdTagName:
            return "GenTagName";
        case IrInstGenIdFieldParentPtr:
            return "GenFieldParentPtr";
        case IrInstGenIdAlignCast:
            return "GenAlignCast";
        case IrInstGenIdErrorReturnTrace:
            return "GenErrorReturnTrace";
        case IrInstGenIdAtomicRmw:
            return "GenAtomicRmw";
        case IrInstGenIdAtomicLoad:
            return "GenAtomicLoad";
        case IrInstGenIdAtomicStore:
            return "GenAtomicStore";
        case IrInstGenIdSaveErrRetAddr:
            return "GenSaveErrRetAddr";
        case IrInstGenIdVectorToArray:
            return "GenVectorToArray";
        case IrInstGenIdArrayToVector:
            return "GenArrayToVector";
        case IrInstGenIdAssertZero:
            return "GenAssertZero";
        case IrInstGenIdAssertNonNull:
            return "GenAssertNonNull";
        case IrInstGenIdAlloca:
            return "GenAlloca";
        case IrInstGenIdPtrOfArrayToSlice:
            return "GenPtrOfArrayToSlice";
        case IrInstGenIdSuspendBegin:
            return "GenSuspendBegin";
        case IrInstGenIdSuspendFinish:
            return "GenSuspendFinish";
        case IrInstGenIdAwait:
            return "GenAwait";
        case IrInstGenIdResume:
            return "GenResume";
        case IrInstGenIdSpillBegin:
            return "GenSpillBegin";
        case IrInstGenIdSpillEnd:
            return "GenSpillEnd";
        case IrInstGenIdVectorExtractElem:
            return "GenVectorExtractElem";
        case IrInstGenIdBinaryNot:
            return "GenBinaryNot";
        case IrInstGenIdNegation:
            return "GenNegation";
        case IrInstGenIdNegationWrapping:
            return "GenNegationWrapping";
        case IrInstGenIdWasmMemorySize:
            return "GenWasmMemorySize";
        case IrInstGenIdWasmMemoryGrow:
            return "GenWasmMemoryGrow";
    }
    zig_unreachable();
}

static void ir_print_indent_src(IrPrintSrc *irp) {
    for (int i = 0; i < irp->indent; i += 1) {
        fprintf(irp->f, " ");
    }
}

static void ir_print_indent_gen(IrPrintGen *irp) {
    for (int i = 0; i < irp->indent; i += 1) {
        fprintf(irp->f, " ");
    }
}

static void ir_print_prefix_src(IrPrintSrc *irp, IrInstSrc *instruction, bool trailing) {
    ir_print_indent_src(irp);
    const char mark = trailing ? ':' : '#';
    const char *type_name;
    if (instruction->id == IrInstSrcIdConst) {
        type_name = buf_ptr(&reinterpret_cast<IrInstSrcConst *>(instruction)->value->type->name);
    } else if (instruction->is_noreturn) {
        type_name = "noreturn";
    } else {
        type_name = "(unknown)";
    }
    const char *ref_count = ir_inst_src_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%" PRIu32 "", instruction->base.ref_count));
    fprintf(irp->f, "%c%-3" PRIu32 "| %-22s| %-12s| %-2s| ", mark, instruction->base.debug_id,
        ir_inst_src_type_str(instruction->id), type_name, ref_count);
}

static void ir_print_prefix_gen(IrPrintGen *irp, IrInstGen *instruction, bool trailing) {
    ir_print_indent_gen(irp);
    const char mark = trailing ? ':' : '#';
    const char *type_name = instruction->value->type ? buf_ptr(&instruction->value->type->name) : "(unknown)";
    const char *ref_count = ir_inst_gen_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%" PRIu32 "", instruction->base.ref_count));
    fprintf(irp->f, "%c%-3" PRIu32 "| %-22s| %-12s| %-2s| ", mark, instruction->base.debug_id,
        ir_inst_gen_type_str(instruction->id), type_name, ref_count);
}

static void ir_print_var_src(IrPrintSrc *irp, IrInstSrc *inst) {
    fprintf(irp->f, "#%" PRIu32 "", inst->base.debug_id);
}

static void ir_print_var_gen(IrPrintGen *irp, IrInstGen *inst) {
    fprintf(irp->f, "#%" PRIu32 "", inst->base.debug_id);
    if (irp->printed.maybe_get(inst) == nullptr) {
        irp->printed.put(inst, 0);
        irp->pending.append(inst);
    }
}

static void ir_print_other_inst_src(IrPrintSrc *irp, IrInstSrc *inst) {
    if (inst == nullptr) {
        fprintf(irp->f, "(null)");
        return;
    }
    ir_print_var_src(irp, inst);
}

static void ir_print_const_value(CodeGen *g, FILE *f, ZigValue *const_val) {
    Buf buf = BUF_INIT;
    buf_resize(&buf, 0);
    render_const_value(g, &buf, const_val);
    fprintf(f, "%s", buf_ptr(&buf));
}

static void ir_print_other_inst_gen(IrPrintGen *irp, IrInstGen *inst) {
    if (inst == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_var_gen(irp, inst);
    }
}

static void ir_print_other_block(IrPrintSrc *irp, IrBasicBlockSrc *bb) {
    if (bb == nullptr) {
        fprintf(irp->f, "(null block)");
    } else {
        fprintf(irp->f, "$%s_%" PRIu32 "", bb->name_hint, bb->debug_id);
    }
}

static void ir_print_other_block_gen(IrPrintGen *irp, IrBasicBlockGen *bb) {
    if (bb == nullptr) {
        fprintf(irp->f, "(null block)");
    } else {
        fprintf(irp->f, "$%s_%" PRIu32 "", bb->name_hint, bb->debug_id);
    }
}

static void ir_print_return_src(IrPrintSrc *irp, IrInstSrcReturn *inst) {
    fprintf(irp->f, "return ");
    ir_print_other_inst_src(irp, inst->operand);
}

static void ir_print_return_gen(IrPrintGen *irp, IrInstGenReturn *inst) {
    fprintf(irp->f, "return ");
    ir_print_other_inst_gen(irp, inst->operand);
}

static void ir_print_const(IrPrintSrc *irp, IrInstSrcConst *const_instruction) {
    ir_print_const_value(irp->codegen, irp->f, const_instruction->value);
}

static void ir_print_const(IrPrintGen *irp, IrInstGenConst *const_instruction) {
    ir_print_const_value(irp->codegen, irp->f, const_instruction->base.value);
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

static void ir_print_un_op(IrPrintSrc *irp, IrInstSrcUnOp *inst) {
    fprintf(irp->f, "%s ", ir_un_op_id_str(inst->op_id));
    ir_print_other_inst_src(irp, inst->value);
}

static void ir_print_bin_op(IrPrintSrc *irp, IrInstSrcBinOp *bin_op_instruction) {
    ir_print_other_inst_src(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_inst_src(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_bin_op(IrPrintGen *irp, IrInstGenBinOp *bin_op_instruction) {
    ir_print_other_inst_gen(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_inst_gen(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_merge_err_sets(IrPrintSrc *irp, IrInstSrcMergeErrSets *instruction) {
    ir_print_other_inst_src(irp, instruction->op1);
    fprintf(irp->f, " || ");
    ir_print_other_inst_src(irp, instruction->op2);
    if (instruction->type_name != nullptr) {
        fprintf(irp->f, " // name=%s", buf_ptr(instruction->type_name));
    }
}

static void ir_print_decl_var_src(IrPrintSrc *irp, IrInstSrcDeclVar *decl_var_instruction) {
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = decl_var_instruction->var->name;
    if (decl_var_instruction->var_type) {
        fprintf(irp->f, "%s %s: ", var_or_const, name);
        ir_print_other_inst_src(irp, decl_var_instruction->var_type);
        fprintf(irp->f, " ");
    } else {
        fprintf(irp->f, "%s %s ", var_or_const, name);
    }
    if (decl_var_instruction->align_value) {
        fprintf(irp->f, "align ");
        ir_print_other_inst_src(irp, decl_var_instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "= ");
    ir_print_other_inst_src(irp, decl_var_instruction->ptr);
    if (decl_var_instruction->var->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_inst_src(irp, decl_var_instruction->var->is_comptime);
    }
}

static const char *cast_op_str(CastOp op) {
    switch (op) {
        case CastOpNoCast: return "NoCast";
        case CastOpNoop: return "NoOp";
        case CastOpIntToFloat: return "IntToFloat";
        case CastOpFloatToInt: return "FloatToInt";
        case CastOpBoolToInt: return "BoolToInt";
        case CastOpNumLitToConcrete: return "NumLitToConcrate";
        case CastOpErrSet: return "ErrSet";
        case CastOpBitCast: return "BitCast";
    }
    zig_unreachable();
}

static void ir_print_cast(IrPrintGen *irp, IrInstGenCast *cast_instruction) {
    fprintf(irp->f, "%s cast ", cast_op_str(cast_instruction->cast_op));
    ir_print_other_inst_gen(irp, cast_instruction->value);
}

static void ir_print_result_loc_var(IrPrintSrc *irp, ResultLocVar *result_loc_var) {
    fprintf(irp->f, "var(");
    ir_print_other_inst_src(irp, result_loc_var->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_instruction(IrPrintSrc *irp, ResultLocInstruction *result_loc_inst) {
    fprintf(irp->f, "inst(");
    ir_print_other_inst_src(irp, result_loc_inst->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_peer(IrPrintSrc *irp, ResultLocPeer *result_loc_peer) {
    fprintf(irp->f, "peer(next=");
    ir_print_other_block(irp, result_loc_peer->next_bb);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_bit_cast(IrPrintSrc *irp, ResultLocBitCast *result_loc_bit_cast) {
    fprintf(irp->f, "bitcast(ty=");
    ir_print_other_inst_src(irp, result_loc_bit_cast->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc_cast(IrPrintSrc *irp, ResultLocCast *result_loc_cast) {
    fprintf(irp->f, "cast(ty=");
    ir_print_other_inst_src(irp, result_loc_cast->base.source_instruction);
    fprintf(irp->f, ")");
}

static void ir_print_result_loc(IrPrintSrc *irp, ResultLoc *result_loc) {
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

static void ir_print_call_extra(IrPrintSrc *irp, IrInstSrcCallExtra *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_inst_src(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=");
    ir_print_other_inst_src(irp, instruction->args);
    fprintf(irp->f, ", result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_async_call_extra(IrPrintSrc *irp, IrInstSrcAsyncCallExtra *instruction) {
    fprintf(irp->f, "modifier=");
    ir_print_call_modifier(irp->f, instruction->modifier);
    fprintf(irp->f, ", fn=");
    ir_print_other_inst_src(irp, instruction->fn_ref);
    if (instruction->ret_ptr != nullptr) {
        fprintf(irp->f, ", ret_ptr=");
        ir_print_other_inst_src(irp, instruction->ret_ptr);
    }
    fprintf(irp->f, ", new_stack=");
    ir_print_other_inst_src(irp, instruction->new_stack);
    fprintf(irp->f, ", args=");
    ir_print_other_inst_src(irp, instruction->args);
    fprintf(irp->f, ", result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_call_args(IrPrintSrc *irp, IrInstSrcCallArgs *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_inst_src(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=(");
    for (size_t i = 0; i < instruction->args_len; i += 1) {
        IrInstSrc *arg = instruction->args_ptr[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, arg);
    }
    fprintf(irp->f, "), result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_call_src(IrPrintSrc *irp, IrInstSrcCall *call_instruction) {
    ir_print_call_modifier(irp->f, call_instruction->modifier);
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_inst_src(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstSrc *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, call_instruction->result_loc);
}

static void ir_print_call_gen(IrPrintGen *irp, IrInstGenCall *call_instruction) {
    ir_print_call_modifier(irp->f, call_instruction->modifier);
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_inst_gen(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstGen *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_gen(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, call_instruction->result_loc);
}

static void ir_print_cond_br(IrPrintSrc *irp, IrInstSrcCondBr *inst) {
    fprintf(irp->f, "if (");
    ir_print_other_inst_src(irp, inst->condition);
    fprintf(irp->f, ") ");
    ir_print_other_block(irp, inst->then_block);
    fprintf(irp->f, " else ");
    ir_print_other_block(irp, inst->else_block);
    if (inst->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_inst_src(irp, inst->is_comptime);
    }
}

static void ir_print_cond_br(IrPrintGen *irp, IrInstGenCondBr *inst) {
    fprintf(irp->f, "if (");
    ir_print_other_inst_gen(irp, inst->condition);
    fprintf(irp->f, ") ");
    ir_print_other_block_gen(irp, inst->then_block);
    fprintf(irp->f, " else ");
    ir_print_other_block_gen(irp, inst->else_block);
}

static void ir_print_br(IrPrintSrc *irp, IrInstSrcBr *br_instruction) {
    fprintf(irp->f, "goto ");
    ir_print_other_block(irp, br_instruction->dest_block);
    if (br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_inst_src(irp, br_instruction->is_comptime);
    }
}

static void ir_print_br(IrPrintGen *irp, IrInstGenBr *inst) {
    fprintf(irp->f, "goto ");
    ir_print_other_block_gen(irp, inst->dest_block);
}

static void ir_print_phi(IrPrintSrc *irp, IrInstSrcPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlockSrc *incoming_block = phi_instruction->incoming_blocks[i];
        IrInstSrc *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_inst_src(irp, incoming_value);
    }
}

static void ir_print_phi(IrPrintGen *irp, IrInstGenPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlockGen *incoming_block = phi_instruction->incoming_blocks[i];
        IrInstGen *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block_gen(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_inst_gen(irp, incoming_value);
    }
}

static void ir_print_container_init_list(IrPrintSrc *irp, IrInstSrcContainerInitList *instruction) {
    fprintf(irp->f, "{");
    if (instruction->item_count > 50) {
        fprintf(irp->f, "...(%" ZIG_PRI_usize " items)...", instruction->item_count);
    } else {
        for (size_t i = 0; i < instruction->item_count; i += 1) {
            IrInstSrc *result_loc = instruction->elem_result_loc_list[i];
            if (i != 0)
                fprintf(irp->f, ", ");
            ir_print_other_inst_src(irp, result_loc);
        }
    }
    fprintf(irp->f, "}result=");
    ir_print_other_inst_src(irp, instruction->result_loc);
}

static void ir_print_container_init_fields(IrPrintSrc *irp, IrInstSrcContainerInitFields *instruction) {
    fprintf(irp->f, "{");
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstSrcContainerInitFieldsField *field = &instruction->fields[i];
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(field->name));
        ir_print_other_inst_src(irp, field->result_loc);
    }
    fprintf(irp->f, "}result=");
    ir_print_other_inst_src(irp, instruction->result_loc);
}

static void ir_print_unreachable(IrPrintSrc *irp, IrInstSrcUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_unreachable(IrPrintGen *irp, IrInstGenUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_elem_ptr(IrPrintSrc *irp, IrInstSrcElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_src(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_elem_ptr(IrPrintGen *irp, IrInstGenElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_gen(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_gen(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_var_ptr(IrPrintSrc *irp, IrInstSrcVarPtr *instruction) {
    fprintf(irp->f, "&%s", instruction->var->name);
}

static void ir_print_var_ptr(IrPrintGen *irp, IrInstGenVarPtr *instruction) {
    fprintf(irp->f, "&%s", instruction->var->name);
}

static void ir_print_return_ptr(IrPrintGen *irp, IrInstGenReturnPtr *instruction) {
    fprintf(irp->f, "@ReturnPtr");
}

static void ir_print_load_ptr(IrPrintSrc *irp, IrInstSrcLoadPtr *instruction) {
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ".*");
}

static void ir_print_load_ptr_gen(IrPrintGen *irp, IrInstGenLoadPtr *instruction) {
    fprintf(irp->f, "loadptr(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_store_ptr(IrPrintSrc *irp, IrInstSrcStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_src(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_store_ptr(IrPrintGen *irp, IrInstGenStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_gen(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_vector_store_elem(IrPrintGen *irp, IrInstGenVectorStoreElem *instruction) {
    fprintf(irp->f, "vector_ptr=");
    ir_print_var_gen(irp, instruction->vector_ptr);
    fprintf(irp->f, ",index=");
    ir_print_var_gen(irp, instruction->index);
    fprintf(irp->f, ",value=");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_typeof(IrPrintSrc *irp, IrInstSrcTypeOf *instruction) {
    fprintf(irp->f, "@TypeOf(");
    if (instruction->value_count == 1) {
        ir_print_other_inst_src(irp, instruction->value.scalar);
    } else {
        for (size_t i = 0; i < instruction->value_count; i += 1) {
            ir_print_other_inst_src(irp, instruction->value.list[i]);
        }
    }
    fprintf(irp->f, ")");
}

static void ir_print_binary_not(IrPrintGen *irp, IrInstGenBinaryNot *instruction) {
    fprintf(irp->f, "~");
    ir_print_other_inst_gen(irp, instruction->operand);
}

static void ir_print_negation(IrPrintGen *irp, IrInstGenNegation *instruction) {
    fprintf(irp->f, "-");
    ir_print_other_inst_gen(irp, instruction->operand);
}

static void ir_print_negation_wrapping(IrPrintGen *irp, IrInstGenNegationWrapping *instruction) {
    fprintf(irp->f, "-%%");
    ir_print_other_inst_gen(irp, instruction->operand);
}


static void ir_print_field_ptr(IrPrintSrc *irp, IrInstSrcFieldPtr *instruction) {
    if (instruction->field_name_buffer) {
        fprintf(irp->f, "fieldptr ");
        ir_print_other_inst_src(irp, instruction->container_ptr);
        fprintf(irp->f, ".%s", buf_ptr(instruction->field_name_buffer));
    } else {
        assert(instruction->field_name_expr);
        fprintf(irp->f, "@field(");
        ir_print_other_inst_src(irp, instruction->container_ptr);
        fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, instruction->field_name_expr);
        fprintf(irp->f, ")");
    }
}

static void ir_print_struct_field_ptr(IrPrintGen *irp, IrInstGenStructFieldPtr *instruction) {
    fprintf(irp->f, "@StructFieldPtr(&");
    ir_print_other_inst_gen(irp, instruction->struct_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_union_field_ptr(IrPrintGen *irp, IrInstGenUnionFieldPtr *instruction) {
    fprintf(irp->f, "@UnionFieldPtr(&");
    ir_print_other_inst_gen(irp, instruction->union_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->enum_field->name));
    fprintf(irp->f, ")");
}

static void ir_print_set_cold(IrPrintSrc *irp, IrInstSrcSetCold *instruction) {
    fprintf(irp->f, "@setCold(");
    ir_print_other_inst_src(irp, instruction->is_cold);
    fprintf(irp->f, ")");
}

static void ir_print_set_runtime_safety(IrPrintSrc *irp, IrInstSrcSetRuntimeSafety *instruction) {
    fprintf(irp->f, "@setRuntimeSafety(");
    ir_print_other_inst_src(irp, instruction->safety_on);
    fprintf(irp->f, ")");
}

static void ir_print_set_float_mode(IrPrintSrc *irp, IrInstSrcSetFloatMode *instruction) {
    fprintf(irp->f, "@setFloatMode(");
    ir_print_other_inst_src(irp, instruction->scope_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->mode_value);
    fprintf(irp->f, ")");
}

static void ir_print_array_type(IrPrintSrc *irp, IrInstSrcArrayType *instruction) {
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->size);
    if (instruction->sentinel != nullptr) {
        fprintf(irp->f, ":");
        ir_print_other_inst_src(irp, instruction->sentinel);
    }
    fprintf(irp->f, "]");
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_slice_type(IrPrintSrc *irp, IrInstSrcSliceType *instruction) {
    const char *const_kw = instruction->is_const ? "const " : "";
    fprintf(irp->f, "[]%s", const_kw);
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_any_frame_type(IrPrintSrc *irp, IrInstSrcAnyFrameType *instruction) {
    if (instruction->payload_type == nullptr) {
        fprintf(irp->f, "anyframe");
    } else {
        fprintf(irp->f, "anyframe->");
        ir_print_other_inst_src(irp, instruction->payload_type);
    }
}

static void ir_print_asm_src(IrPrintSrc *irp, IrInstSrcAsm *instruction) {
    assert(instruction->base.base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.base.source_node->data.asm_expr;
    const char *volatile_kw = instruction->has_side_effects ? " volatile" : "";
    fprintf(irp->f, "asm%s (", volatile_kw);
    ir_print_other_inst_src(irp, instruction->asm_template);

    for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");

        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_output->asm_symbolic_name),
                buf_ptr(asm_output->constraint));
        if (asm_output->return_type) {
            fprintf(irp->f, "-> ");
            ir_print_other_inst_src(irp, instruction->output_types[i]);
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
        ir_print_other_inst_src(irp, instruction->input_list[i]);
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

static void ir_print_asm_gen(IrPrintGen *irp, IrInstGenAsm *instruction) {
    assert(instruction->base.base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.base.source_node->data.asm_expr;
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
            ir_print_other_inst_gen(irp, instruction->output_types[i]);
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
        ir_print_other_inst_gen(irp, instruction->input_list[i]);
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

static void ir_print_size_of(IrPrintSrc *irp, IrInstSrcSizeOf *instruction) {
    if (instruction->bit_size)
        fprintf(irp->f, "@bitSizeOf(");
    else
        fprintf(irp->f, "@sizeOf(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_test_non_null(IrPrintSrc *irp, IrInstSrcTestNonNull *instruction) {
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_test_non_null(IrPrintGen *irp, IrInstGenTestNonNull *instruction) {
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_optional_unwrap_ptr(IrPrintSrc *irp, IrInstSrcOptionalUnwrapPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_src(irp, instruction->base_ptr);
    fprintf(irp->f, ".*.?");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_optional_unwrap_ptr(IrPrintGen *irp, IrInstGenOptionalUnwrapPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_gen(irp, instruction->base_ptr);
    fprintf(irp->f, ".*.?");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_clz(IrPrintSrc *irp, IrInstSrcClz *instruction) {
    fprintf(irp->f, "@clz(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_clz(IrPrintGen *irp, IrInstGenClz *instruction) {
    fprintf(irp->f, "@clz(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrintSrc *irp, IrInstSrcCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrintGen *irp, IrInstGenCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_pop_count(IrPrintSrc *irp, IrInstSrcPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_pop_count(IrPrintGen *irp, IrInstGenPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bswap(IrPrintSrc *irp, IrInstSrcBswap *instruction) {
    fprintf(irp->f, "@byteSwap(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bswap(IrPrintGen *irp, IrInstGenBswap *instruction) {
    fprintf(irp->f, "@byteSwap(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bit_reverse(IrPrintSrc *irp, IrInstSrcBitReverse *instruction) {
    fprintf(irp->f, "@bitReverse(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bit_reverse(IrPrintGen *irp, IrInstGenBitReverse *instruction) {
    fprintf(irp->f, "@bitReverse(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_switch_br(IrPrintSrc *irp, IrInstSrcSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_inst_src(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstSrcSwitchBrCase *this_case = &instruction->cases[i];
        ir_print_other_inst_src(irp, this_case->value);
        fprintf(irp->f, " => ");
        ir_print_other_block(irp, this_case->block);
        fprintf(irp->f, ", ");
    }
    fprintf(irp->f, "else => ");
    ir_print_other_block(irp, instruction->else_block);
    if (instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_inst_src(irp, instruction->is_comptime);
    }
}

static void ir_print_switch_br(IrPrintGen *irp, IrInstGenSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_inst_gen(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstGenSwitchBrCase *this_case = &instruction->cases[i];
        ir_print_other_inst_gen(irp, this_case->value);
        fprintf(irp->f, " => ");
        ir_print_other_block_gen(irp, this_case->block);
        fprintf(irp->f, ", ");
    }
    fprintf(irp->f, "else => ");
    ir_print_other_block_gen(irp, instruction->else_block);
}

static void ir_print_switch_var(IrPrintSrc *irp, IrInstSrcSwitchVar *instruction) {
    fprintf(irp->f, "switchvar ");
    ir_print_other_inst_src(irp, instruction->target_value_ptr);
    for (size_t i = 0; i < instruction->prongs_len; i += 1) {
        fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, instruction->prongs_ptr[i]);
    }
}

static void ir_print_switch_else_var(IrPrintSrc *irp, IrInstSrcSwitchElseVar *instruction) {
    fprintf(irp->f, "switchelsevar ");
    ir_print_other_inst_src(irp, &instruction->switch_br->base);
}

static void ir_print_switch_target(IrPrintSrc *irp, IrInstSrcSwitchTarget *instruction) {
    fprintf(irp->f, "switchtarget ");
    ir_print_other_inst_src(irp, instruction->target_value_ptr);
}

static void ir_print_union_tag(IrPrintGen *irp, IrInstGenUnionTag *instruction) {
    fprintf(irp->f, "uniontag ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_import(IrPrintSrc *irp, IrInstSrcImport *instruction) {
    fprintf(irp->f, "@import(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_ref(IrPrintSrc *irp, IrInstSrcRef *instruction) {
    fprintf(irp->f, "ref ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_ref_gen(IrPrintGen *irp, IrInstGenRef *instruction) {
    fprintf(irp->f, "@ref(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_compile_err(IrPrintSrc *irp, IrInstSrcCompileErr *instruction) {
    fprintf(irp->f, "@compileError(");
    ir_print_other_inst_src(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_compile_log(IrPrintSrc *irp, IrInstSrcCompileLog *instruction) {
    fprintf(irp->f, "@compileLog(");
    for (size_t i = 0; i < instruction->msg_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        IrInstSrc *msg = instruction->msg_list[i];
        ir_print_other_inst_src(irp, msg);
    }
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrintSrc *irp, IrInstSrcErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrintGen *irp, IrInstGenErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_import(IrPrintSrc *irp, IrInstSrcCImport *instruction) {
    fprintf(irp->f, "@cImport(...)");
}

static void ir_print_c_include(IrPrintSrc *irp, IrInstSrcCInclude *instruction) {
    fprintf(irp->f, "@cInclude(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_c_define(IrPrintSrc *irp, IrInstSrcCDefine *instruction) {
    fprintf(irp->f, "@cDefine(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_undef(IrPrintSrc *irp, IrInstSrcCUndef *instruction) {
    fprintf(irp->f, "@cUndef(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_embed_file(IrPrintSrc *irp, IrInstSrcEmbedFile *instruction) {
    fprintf(irp->f, "@embedFile(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_cmpxchg_src(IrPrintSrc *irp, IrInstSrcCmpxchg *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->new_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->success_order_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->failure_order_value);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_cmpxchg_gen(IrPrintGen *irp, IrInstGenCmpxchg *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->new_value);
    fprintf(irp->f, ", TODO print atomic orders)result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_fence(IrPrintSrc *irp, IrInstSrcFence *instruction) {
    fprintf(irp->f, "@fence(");
    ir_print_other_inst_src(irp, instruction->order);
    fprintf(irp->f, ")");
}

static const char *atomic_order_str(AtomicOrder order) {
    switch (order) {
        case AtomicOrderUnordered: return "Unordered";
        case AtomicOrderMonotonic: return "Monotonic";
        case AtomicOrderAcquire: return "Acquire";
        case AtomicOrderRelease: return "Release";
        case AtomicOrderAcqRel: return "AcqRel";
        case AtomicOrderSeqCst: return "SeqCst";
    }
    zig_unreachable();
}

static void ir_print_fence(IrPrintGen *irp, IrInstGenFence *instruction) {
    fprintf(irp->f, "fence %s", atomic_order_str(instruction->order));
}

static void ir_print_truncate(IrPrintSrc *irp, IrInstSrcTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_truncate(IrPrintGen *irp, IrInstGenTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_cast(IrPrintSrc *irp, IrInstSrcIntCast *instruction) {
    fprintf(irp->f, "@intCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_cast(IrPrintSrc *irp, IrInstSrcFloatCast *instruction) {
    fprintf(irp->f, "@floatCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_err_set_cast(IrPrintSrc *irp, IrInstSrcErrSetCast *instruction) {
    fprintf(irp->f, "@errSetCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_float(IrPrintSrc *irp, IrInstSrcIntToFloat *instruction) {
    fprintf(irp->f, "@intToFloat(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_to_int(IrPrintSrc *irp, IrInstSrcFloatToInt *instruction) {
    fprintf(irp->f, "@floatToInt(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_bool_to_int(IrPrintSrc *irp, IrInstSrcBoolToInt *instruction) {
    fprintf(irp->f, "@boolToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_vector_type(IrPrintSrc *irp, IrInstSrcVectorType *instruction) {
    fprintf(irp->f, "@Vector(");
    ir_print_other_inst_src(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->elem_type);
    fprintf(irp->f, ")");
}

static void ir_print_shuffle_vector(IrPrintSrc *irp, IrInstSrcShuffleVector *instruction) {
    fprintf(irp->f, "@shuffle(");
    ir_print_other_inst_src(irp, instruction->scalar_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->a);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->b);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->mask);
    fprintf(irp->f, ")");
}

static void ir_print_shuffle_vector(IrPrintGen *irp, IrInstGenShuffleVector *instruction) {
    fprintf(irp->f, "@shuffle(");
    ir_print_other_inst_gen(irp, instruction->a);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->b);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->mask);
    fprintf(irp->f, ")");
}

static void ir_print_splat_src(IrPrintSrc *irp, IrInstSrcSplat *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_inst_src(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_splat_gen(IrPrintGen *irp, IrInstGenSplat *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_inst_gen(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_bool_not(IrPrintSrc *irp, IrInstSrcBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_bool_not(IrPrintGen *irp, IrInstGenBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_wasm_memory_size(IrPrintSrc *irp, IrInstSrcWasmMemorySize *instruction) {
    fprintf(irp->f, "@wasmMemorySize(");
    ir_print_other_inst_src(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_size(IrPrintGen *irp, IrInstGenWasmMemorySize *instruction) {
    fprintf(irp->f, "@wasmMemorySize(");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_grow(IrPrintSrc *irp, IrInstSrcWasmMemoryGrow *instruction) {
    fprintf(irp->f, "@wasmMemoryGrow(");
    ir_print_other_inst_src(irp, instruction->index);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->delta);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_grow(IrPrintGen *irp, IrInstGenWasmMemoryGrow *instruction) {
    fprintf(irp->f, "@wasmMemoryGrow(");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->delta);
    fprintf(irp->f, ")");
}

static void ir_print_builtin_src(IrPrintSrc *irp, IrInstSrcSrc *instruction) {
    fprintf(irp->f, "@src()");
}

static void ir_print_memset(IrPrintSrc *irp, IrInstSrcMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_inst_src(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memset(IrPrintGen *irp, IrInstGenMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_inst_gen(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrintSrc *irp, IrInstSrcMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_inst_src(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrintGen *irp, IrInstGenMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_inst_gen(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_slice_src(IrPrintSrc *irp, IrInstSrcSlice *instruction) {
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_inst_src(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_slice_gen(IrPrintGen *irp, IrInstGenSlice *instruction) {
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_gen(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_inst_gen(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_breakpoint(IrPrintSrc *irp, IrInstSrcBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_breakpoint(IrPrintGen *irp, IrInstGenBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_frame_address(IrPrintSrc *irp, IrInstSrcFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_frame_address(IrPrintGen *irp, IrInstGenFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_handle(IrPrintSrc *irp, IrInstSrcFrameHandle *instruction) {
    fprintf(irp->f, "@frame()");
}

static void ir_print_handle(IrPrintGen *irp, IrInstGenFrameHandle *instruction) {
    fprintf(irp->f, "@frame()");
}

static void ir_print_frame_type(IrPrintSrc *irp, IrInstSrcFrameType *instruction) {
    fprintf(irp->f, "@Frame(");
    ir_print_other_inst_src(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_src(IrPrintSrc *irp, IrInstSrcFrameSize *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_inst_src(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_gen(IrPrintGen *irp, IrInstGenFrameSize *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_inst_gen(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_return_address(IrPrintSrc *irp, IrInstSrcReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_return_address(IrPrintGen *irp, IrInstGenReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_align_of(IrPrintSrc *irp, IrInstSrcAlignOf *instruction) {
    fprintf(irp->f, "@alignOf(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_overflow_op(IrPrintSrc *irp, IrInstSrcOverflowOp *instruction) {
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
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->op1);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->op2);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->result_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_overflow_op(IrPrintGen *irp, IrInstGenOverflowOp *instruction) {
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
    ir_print_other_inst_gen(irp, instruction->op1);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->op2);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->result_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err_src(IrPrintSrc *irp, IrInstSrcTestErr *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_inst_src(irp, instruction->base_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err_gen(IrPrintGen *irp, IrInstGenTestErr *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_inst_gen(irp, instruction->err_union);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrintSrc *irp, IrInstSrcUnwrapErrCode *instruction) {
    fprintf(irp->f, "UnwrapErrorCode(");
    ir_print_other_inst_src(irp, instruction->err_union_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrintGen *irp, IrInstGenUnwrapErrCode *instruction) {
    fprintf(irp->f, "UnwrapErrorCode(");
    ir_print_other_inst_gen(irp, instruction->err_union_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_payload(IrPrintSrc *irp, IrInstSrcUnwrapErrPayload *instruction) {
    fprintf(irp->f, "ErrorUnionFieldPayload(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")safety=%d,init=%d",instruction->safety_check_on, instruction->initializing);
}

static void ir_print_unwrap_err_payload(IrPrintGen *irp, IrInstGenUnwrapErrPayload *instruction) {
    fprintf(irp->f, "ErrorUnionFieldPayload(");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ")safety=%d,init=%d",instruction->safety_check_on, instruction->initializing);
}

static void ir_print_optional_wrap(IrPrintGen *irp, IrInstGenOptionalWrap *instruction) {
    fprintf(irp->f, "@optionalWrap(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_err_wrap_code(IrPrintGen *irp, IrInstGenErrWrapCode *instruction) {
    fprintf(irp->f, "@errWrapCode(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_err_wrap_payload(IrPrintGen *irp, IrInstGenErrWrapPayload *instruction) {
    fprintf(irp->f, "@errWrapPayload(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_fn_proto(IrPrintSrc *irp, IrInstSrcFnProto *instruction) {
    fprintf(irp->f, "fn(");
    for (size_t i = 0; i < instruction->base.base.source_node->data.fn_proto.params.length; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        if (instruction->is_var_args && i == instruction->base.base.source_node->data.fn_proto.params.length - 1) {
            fprintf(irp->f, "...");
        } else {
            ir_print_other_inst_src(irp, instruction->param_types[i]);
        }
    }
    fprintf(irp->f, ")");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, " align ");
        ir_print_other_inst_src(irp, instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "->");
    ir_print_other_inst_src(irp, instruction->return_type);
}

static void ir_print_test_comptime(IrPrintSrc *irp, IrInstSrcTestComptime *instruction) {
    fprintf(irp->f, "@testComptime(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_src(IrPrintSrc *irp, IrInstSrcPtrCast *instruction) {
    fprintf(irp->f, "@ptrCast(");
    if (instruction->dest_type) {
        ir_print_other_inst_src(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_gen(IrPrintGen *irp, IrInstGenPtrCast *instruction) {
    fprintf(irp->f, "@ptrCast(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_implicit_cast(IrPrintSrc *irp, IrInstSrcImplicitCast *instruction) {
    fprintf(irp->f, "@implicitCast(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_cast->base);
}

static void ir_print_bit_cast_src(IrPrintSrc *irp, IrInstSrcBitCast *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_bit_cast->base);
}

static void ir_print_bit_cast_gen(IrPrintGen *irp, IrInstGenBitCast *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_widen_or_shorten(IrPrintGen *irp, IrInstGenWidenOrShorten *instruction) {
    fprintf(irp->f, "WidenOrShorten(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrintSrc *irp, IrInstSrcPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrintGen *irp, IrInstGenPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrintSrc *irp, IrInstSrcIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrintGen *irp, IrInstGenIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrintSrc *irp, IrInstSrcIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrintGen *irp, IrInstGenIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_enum_to_int(IrPrintSrc *irp, IrInstSrcEnumToInt *instruction) {
    fprintf(irp->f, "@enumToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_check_runtime_scope(IrPrintSrc *irp, IrInstSrcCheckRuntimeScope *instruction) {
    fprintf(irp->f, "@checkRuntimeScope(");
    ir_print_other_inst_src(irp, instruction->scope_is_comptime);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->is_comptime);
    fprintf(irp->f, ")");
}

static void ir_print_array_to_vector(IrPrintGen *irp, IrInstGenArrayToVector *instruction) {
    fprintf(irp->f, "ArrayToVector(");
    ir_print_other_inst_gen(irp, instruction->array);
    fprintf(irp->f, ")");
}

static void ir_print_vector_to_array(IrPrintGen *irp, IrInstGenVectorToArray *instruction) {
    fprintf(irp->f, "VectorToArray(");
    ir_print_other_inst_gen(irp, instruction->vector);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_ptr_of_array_to_slice(IrPrintGen *irp, IrInstGenPtrOfArrayToSlice *instruction) {
    fprintf(irp->f, "PtrOfArrayToSlice(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_assert_zero(IrPrintGen *irp, IrInstGenAssertZero *instruction) {
    fprintf(irp->f, "AssertZero(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_assert_non_null(IrPrintGen *irp, IrInstGenAssertNonNull *instruction) {
    fprintf(irp->f, "AssertNonNull(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_alloca_src(IrPrintSrc *irp, IrInstSrcAlloca *instruction) {
    fprintf(irp->f, "Alloca(align=");
    ir_print_other_inst_src(irp, instruction->align);
    fprintf(irp->f, ",name=%s)", instruction->name_hint);
}

static void ir_print_alloca_gen(IrPrintGen *irp, IrInstGenAlloca *instruction) {
    fprintf(irp->f, "Alloca(align=%" PRIu32 ",name=%s)", instruction->align, instruction->name_hint);
}

static void ir_print_end_expr(IrPrintSrc *irp, IrInstSrcEndExpr *instruction) {
    fprintf(irp->f, "EndExpr(result=");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ",value=");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_err(IrPrintSrc *irp, IrInstSrcIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_int_to_err(IrPrintGen *irp, IrInstGenIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrintSrc *irp, IrInstSrcErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrintGen *irp, IrInstGenErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_check_switch_prongs(IrPrintSrc *irp, IrInstSrcCheckSwitchProngs *instruction) {
    fprintf(irp->f, "@checkSwitchProngs(");
    ir_print_other_inst_src(irp, instruction->target_value);
    fprintf(irp->f, ",");
    for (size_t i = 0; i < instruction->range_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        ir_print_other_inst_src(irp, instruction->ranges[i].start);
        fprintf(irp->f, "...");
        ir_print_other_inst_src(irp, instruction->ranges[i].end);
    }
    const char *have_else_str = instruction->else_prong != nullptr ? "yes" : "no";
    fprintf(irp->f, ")else:%s", have_else_str);
}

static void ir_print_check_statement_is_void(IrPrintSrc *irp, IrInstSrcCheckStatementIsVoid *instruction) {
    fprintf(irp->f, "@checkStatementIsVoid(");
    ir_print_other_inst_src(irp, instruction->statement_value);
    fprintf(irp->f, ")");
}

static void ir_print_type_name(IrPrintSrc *irp, IrInstSrcTypeName *instruction) {
    fprintf(irp->f, "typename ");
    ir_print_other_inst_src(irp, instruction->type_value);
}

static void ir_print_tag_name(IrPrintSrc *irp, IrInstSrcTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_tag_name(IrPrintGen *irp, IrInstGenTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_ptr_type(IrPrintSrc *irp, IrInstSrcPtrType *instruction) {
    fprintf(irp->f, "&");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, "align(");
        ir_print_other_inst_src(irp, instruction->align_value);
        fprintf(irp->f, ")");
    }
    const char *const_str = instruction->is_const ? "const " : "";
    const char *volatile_str = instruction->is_volatile ? "volatile " : "";
    fprintf(irp->f, ":%" PRIu32 ":%" PRIu32 " %s%s", instruction->bit_offset_start, instruction->host_int_bytes,
            const_str, volatile_str);
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_decl_ref(IrPrintSrc *irp, IrInstSrcDeclRef *instruction) {
    const char *ptr_str = (instruction->lval != LValNone) ? "ptr " : "";
    fprintf(irp->f, "declref %s%s", ptr_str, buf_ptr(instruction->tld->name));
}

static void ir_print_panic(IrPrintSrc *irp, IrInstSrcPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_inst_src(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_panic(IrPrintGen *irp, IrInstGenPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_inst_gen(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrintSrc *irp, IrInstSrcFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrintGen *irp, IrInstGenFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(%s,", buf_ptr(instruction->field->name));
    ir_print_other_inst_gen(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_byte_offset_of(IrPrintSrc *irp, IrInstSrcByteOffsetOf *instruction) {
    fprintf(irp->f, "@byte_offset_of(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_bit_offset_of(IrPrintSrc *irp, IrInstSrcBitOffsetOf *instruction) {
    fprintf(irp->f, "@bit_offset_of(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_type_info(IrPrintSrc *irp, IrInstSrcTypeInfo *instruction) {
    fprintf(irp->f, "@typeInfo(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_type(IrPrintSrc *irp, IrInstSrcType *instruction) {
    fprintf(irp->f, "@Type(");
    ir_print_other_inst_src(irp, instruction->type_info);
    fprintf(irp->f, ")");
}

static void ir_print_has_field(IrPrintSrc *irp, IrInstSrcHasField *instruction) {
    fprintf(irp->f, "@hasField(");
    ir_print_other_inst_src(irp, instruction->container_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_set_eval_branch_quota(IrPrintSrc *irp, IrInstSrcSetEvalBranchQuota *instruction) {
    fprintf(irp->f, "@setEvalBranchQuota(");
    ir_print_other_inst_src(irp, instruction->new_quota);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrintSrc *irp, IrInstSrcAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    ir_print_other_inst_src(irp, instruction->align_bytes);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrintGen *irp, IrInstGenAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_resolve_result(IrPrintSrc *irp, IrInstSrcResolveResult *instruction) {
    fprintf(irp->f, "ResolveResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_reset_result(IrPrintSrc *irp, IrInstSrcResetResult *instruction) {
    fprintf(irp->f, "ResetResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_set_align_stack(IrPrintSrc *irp, IrInstSrcSetAlignStack *instruction) {
    fprintf(irp->f, "@setAlignStack(");
    ir_print_other_inst_src(irp, instruction->align_bytes);
    fprintf(irp->f, ")");
}

static void ir_print_arg_type(IrPrintSrc *irp, IrInstSrcArgType *instruction) {
    fprintf(irp->f, "@ArgType(");
    ir_print_other_inst_src(irp, instruction->fn_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->arg_index);
    fprintf(irp->f, ")");
}

static void ir_print_enum_tag_type(IrPrintSrc *irp, IrInstSrcTagType *instruction) {
    fprintf(irp->f, "@TagType(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_export(IrPrintSrc *irp, IrInstSrcExport *instruction) {
    fprintf(irp->f, "@export(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ")");
}

static void ir_print_error_return_trace(IrPrintSrc *irp, IrInstSrcErrorReturnTrace *instruction) {
    fprintf(irp->f, "@errorReturnTrace(");
    switch (instruction->optional) {
        case IrInstErrorReturnTraceNull:
            fprintf(irp->f, "Null");
            break;
        case IrInstErrorReturnTraceNonNull:
            fprintf(irp->f, "NonNull");
            break;
    }
    fprintf(irp->f, ")");
}

static void ir_print_error_return_trace(IrPrintGen *irp, IrInstGenErrorReturnTrace *instruction) {
    fprintf(irp->f, "@errorReturnTrace(");
    switch (instruction->optional) {
        case IrInstErrorReturnTraceNull:
            fprintf(irp->f, "Null");
            break;
        case IrInstErrorReturnTraceNonNull:
            fprintf(irp->f, "NonNull");
            break;
    }
    fprintf(irp->f, ")");
}

static void ir_print_error_union(IrPrintSrc *irp, IrInstSrcErrorUnion *instruction) {
    ir_print_other_inst_src(irp, instruction->err_set);
    fprintf(irp->f, "!");
    ir_print_other_inst_src(irp, instruction->payload);
}

static void ir_print_atomic_rmw(IrPrintSrc *irp, IrInstSrcAtomicRmw *instruction) {
    fprintf(irp->f, "@atomicRmw(");
    ir_print_other_inst_src(irp, instruction->operand_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ordering);
    fprintf(irp->f, ")");
}

static void ir_print_atomic_rmw(IrPrintGen *irp, IrInstGenAtomicRmw *instruction) {
    fprintf(irp->f, "@atomicRmw(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",[TODO print op],");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}

static void ir_print_atomic_load(IrPrintSrc *irp, IrInstSrcAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    ir_print_other_inst_src(irp, instruction->operand_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ordering);
    fprintf(irp->f, ")");
}

static void ir_print_atomic_load(IrPrintGen *irp, IrInstGenAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}

static void ir_print_atomic_store(IrPrintSrc *irp, IrInstSrcAtomicStore *instruction) {
    fprintf(irp->f, "@atomicStore(");
    ir_print_other_inst_src(irp, instruction->operand_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ordering);
    fprintf(irp->f, ")");
}

static void ir_print_atomic_store(IrPrintGen *irp, IrInstGenAtomicStore *instruction) {
    fprintf(irp->f, "@atomicStore(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}


static void ir_print_save_err_ret_addr(IrPrintSrc *irp, IrInstSrcSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_save_err_ret_addr(IrPrintGen *irp, IrInstGenSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_add_implicit_return_type(IrPrintSrc *irp, IrInstSrcAddImplicitReturnType *instruction) {
    fprintf(irp->f, "@addImplicitReturnType(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_float_op(IrPrintSrc *irp, IrInstSrcFloatOp *instruction) {
    fprintf(irp->f, "@%s(", float_op_to_name(instruction->fn_id));
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_float_op(IrPrintGen *irp, IrInstGenFloatOp *instruction) {
    fprintf(irp->f, "@%s(", float_op_to_name(instruction->fn_id));
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_mul_add(IrPrintSrc *irp, IrInstSrcMulAdd *instruction) {
    fprintf(irp->f, "@mulAdd(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op1);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op2);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op3);
    fprintf(irp->f, ")");
}

static void ir_print_mul_add(IrPrintGen *irp, IrInstGenMulAdd *instruction) {
    fprintf(irp->f, "@mulAdd(");
    ir_print_other_inst_gen(irp, instruction->op1);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->op2);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->op3);
    fprintf(irp->f, ")");
}

static void ir_print_decl_var_gen(IrPrintGen *irp, IrInstGenDeclVar *decl_var_instruction) {
    ZigVar *var = decl_var_instruction->var;
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = decl_var_instruction->var->name;
    fprintf(irp->f, "%s %s: %s align(%u) = ", var_or_const, name, buf_ptr(&var->var_type->name),
            var->align_bytes);

    ir_print_other_inst_gen(irp, decl_var_instruction->var_ptr);
}

static void ir_print_has_decl(IrPrintSrc *irp, IrInstSrcHasDecl *instruction) {
    fprintf(irp->f, "@hasDecl(");
    ir_print_other_inst_src(irp, instruction->container);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_undeclared_ident(IrPrintSrc *irp, IrInstSrcUndeclaredIdent *instruction) {
    fprintf(irp->f, "@undeclaredIdent(%s)", buf_ptr(instruction->name));
}

static void ir_print_union_init_named_field(IrPrintSrc *irp, IrInstSrcUnionInitNamedField *instruction) {
    fprintf(irp->f, "@unionInit(");
    ir_print_other_inst_src(irp, instruction->union_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->field_result_loc);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_suspend_begin(IrPrintSrc *irp, IrInstSrcSuspendBegin *instruction) {
    fprintf(irp->f, "@suspendBegin()");
}

static void ir_print_suspend_begin(IrPrintGen *irp, IrInstGenSuspendBegin *instruction) {
    fprintf(irp->f, "@suspendBegin()");
}

static void ir_print_suspend_finish(IrPrintSrc *irp, IrInstSrcSuspendFinish *instruction) {
    fprintf(irp->f, "@suspendFinish()");
}

static void ir_print_suspend_finish(IrPrintGen *irp, IrInstGenSuspendFinish *instruction) {
    fprintf(irp->f, "@suspendFinish()");
}

static void ir_print_resume(IrPrintSrc *irp, IrInstSrcResume *instruction) {
    fprintf(irp->f, "resume ");
    ir_print_other_inst_src(irp, instruction->frame);
}

static void ir_print_resume(IrPrintGen *irp, IrInstGenResume *instruction) {
    fprintf(irp->f, "resume ");
    ir_print_other_inst_gen(irp, instruction->frame);
}

static void ir_print_await_src(IrPrintSrc *irp, IrInstSrcAwait *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_inst_src(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_await_gen(IrPrintGen *irp, IrInstGenAwait *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_inst_gen(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_spill_begin(IrPrintSrc *irp, IrInstSrcSpillBegin *instruction) {
    fprintf(irp->f, "@spillBegin(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_spill_begin(IrPrintGen *irp, IrInstGenSpillBegin *instruction) {
    fprintf(irp->f, "@spillBegin(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_spill_end(IrPrintSrc *irp, IrInstSrcSpillEnd *instruction) {
    fprintf(irp->f, "@spillEnd(");
    ir_print_other_inst_src(irp, &instruction->begin->base);
    fprintf(irp->f, ")");
}

static void ir_print_spill_end(IrPrintGen *irp, IrInstGenSpillEnd *instruction) {
    fprintf(irp->f, "@spillEnd(");
    ir_print_other_inst_gen(irp, &instruction->begin->base);
    fprintf(irp->f, ")");
}

static void ir_print_vector_extract_elem(IrPrintGen *irp, IrInstGenVectorExtractElem *instruction) {
    fprintf(irp->f, "@vectorExtractElem(");
    ir_print_other_inst_gen(irp, instruction->vector);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_inst_src(IrPrintSrc *irp, IrInstSrc *instruction, bool trailing) {
    ir_print_prefix_src(irp, instruction, trailing);
    switch (instruction->id) {
        case IrInstSrcIdInvalid:
            zig_unreachable();
        case IrInstSrcIdReturn:
            ir_print_return_src(irp, (IrInstSrcReturn *)instruction);
            break;
        case IrInstSrcIdConst:
            ir_print_const(irp, (IrInstSrcConst *)instruction);
            break;
        case IrInstSrcIdBinOp:
            ir_print_bin_op(irp, (IrInstSrcBinOp *)instruction);
            break;
        case IrInstSrcIdMergeErrSets:
            ir_print_merge_err_sets(irp, (IrInstSrcMergeErrSets *)instruction);
            break;
        case IrInstSrcIdDeclVar:
            ir_print_decl_var_src(irp, (IrInstSrcDeclVar *)instruction);
            break;
        case IrInstSrcIdCallExtra:
            ir_print_call_extra(irp, (IrInstSrcCallExtra *)instruction);
            break;
        case IrInstSrcIdAsyncCallExtra:
            ir_print_async_call_extra(irp, (IrInstSrcAsyncCallExtra *)instruction);
            break;
        case IrInstSrcIdCall:
            ir_print_call_src(irp, (IrInstSrcCall *)instruction);
            break;
        case IrInstSrcIdCallArgs:
            ir_print_call_args(irp, (IrInstSrcCallArgs *)instruction);
            break;
        case IrInstSrcIdUnOp:
            ir_print_un_op(irp, (IrInstSrcUnOp *)instruction);
            break;
        case IrInstSrcIdCondBr:
            ir_print_cond_br(irp, (IrInstSrcCondBr *)instruction);
            break;
        case IrInstSrcIdBr:
            ir_print_br(irp, (IrInstSrcBr *)instruction);
            break;
        case IrInstSrcIdPhi:
            ir_print_phi(irp, (IrInstSrcPhi *)instruction);
            break;
        case IrInstSrcIdContainerInitList:
            ir_print_container_init_list(irp, (IrInstSrcContainerInitList *)instruction);
            break;
        case IrInstSrcIdContainerInitFields:
            ir_print_container_init_fields(irp, (IrInstSrcContainerInitFields *)instruction);
            break;
        case IrInstSrcIdUnreachable:
            ir_print_unreachable(irp, (IrInstSrcUnreachable *)instruction);
            break;
        case IrInstSrcIdElemPtr:
            ir_print_elem_ptr(irp, (IrInstSrcElemPtr *)instruction);
            break;
        case IrInstSrcIdVarPtr:
            ir_print_var_ptr(irp, (IrInstSrcVarPtr *)instruction);
            break;
        case IrInstSrcIdLoadPtr:
            ir_print_load_ptr(irp, (IrInstSrcLoadPtr *)instruction);
            break;
        case IrInstSrcIdStorePtr:
            ir_print_store_ptr(irp, (IrInstSrcStorePtr *)instruction);
            break;
        case IrInstSrcIdTypeOf:
            ir_print_typeof(irp, (IrInstSrcTypeOf *)instruction);
            break;
        case IrInstSrcIdFieldPtr:
            ir_print_field_ptr(irp, (IrInstSrcFieldPtr *)instruction);
            break;
        case IrInstSrcIdSetCold:
            ir_print_set_cold(irp, (IrInstSrcSetCold *)instruction);
            break;
        case IrInstSrcIdSetRuntimeSafety:
            ir_print_set_runtime_safety(irp, (IrInstSrcSetRuntimeSafety *)instruction);
            break;
        case IrInstSrcIdSetFloatMode:
            ir_print_set_float_mode(irp, (IrInstSrcSetFloatMode *)instruction);
            break;
        case IrInstSrcIdArrayType:
            ir_print_array_type(irp, (IrInstSrcArrayType *)instruction);
            break;
        case IrInstSrcIdSliceType:
            ir_print_slice_type(irp, (IrInstSrcSliceType *)instruction);
            break;
        case IrInstSrcIdAnyFrameType:
            ir_print_any_frame_type(irp, (IrInstSrcAnyFrameType *)instruction);
            break;
        case IrInstSrcIdAsm:
            ir_print_asm_src(irp, (IrInstSrcAsm *)instruction);
            break;
        case IrInstSrcIdSizeOf:
            ir_print_size_of(irp, (IrInstSrcSizeOf *)instruction);
            break;
        case IrInstSrcIdTestNonNull:
            ir_print_test_non_null(irp, (IrInstSrcTestNonNull *)instruction);
            break;
        case IrInstSrcIdOptionalUnwrapPtr:
            ir_print_optional_unwrap_ptr(irp, (IrInstSrcOptionalUnwrapPtr *)instruction);
            break;
        case IrInstSrcIdPopCount:
            ir_print_pop_count(irp, (IrInstSrcPopCount *)instruction);
            break;
        case IrInstSrcIdCtz:
            ir_print_ctz(irp, (IrInstSrcCtz *)instruction);
            break;
        case IrInstSrcIdBswap:
            ir_print_bswap(irp, (IrInstSrcBswap *)instruction);
            break;
        case IrInstSrcIdBitReverse:
            ir_print_bit_reverse(irp, (IrInstSrcBitReverse *)instruction);
            break;
        case IrInstSrcIdSwitchBr:
            ir_print_switch_br(irp, (IrInstSrcSwitchBr *)instruction);
            break;
        case IrInstSrcIdSwitchVar:
            ir_print_switch_var(irp, (IrInstSrcSwitchVar *)instruction);
            break;
        case IrInstSrcIdSwitchElseVar:
            ir_print_switch_else_var(irp, (IrInstSrcSwitchElseVar *)instruction);
            break;
        case IrInstSrcIdSwitchTarget:
            ir_print_switch_target(irp, (IrInstSrcSwitchTarget *)instruction);
            break;
        case IrInstSrcIdImport:
            ir_print_import(irp, (IrInstSrcImport *)instruction);
            break;
        case IrInstSrcIdRef:
            ir_print_ref(irp, (IrInstSrcRef *)instruction);
            break;
        case IrInstSrcIdCompileErr:
            ir_print_compile_err(irp, (IrInstSrcCompileErr *)instruction);
            break;
        case IrInstSrcIdCompileLog:
            ir_print_compile_log(irp, (IrInstSrcCompileLog *)instruction);
            break;
        case IrInstSrcIdErrName:
            ir_print_err_name(irp, (IrInstSrcErrName *)instruction);
            break;
        case IrInstSrcIdCImport:
            ir_print_c_import(irp, (IrInstSrcCImport *)instruction);
            break;
        case IrInstSrcIdCInclude:
            ir_print_c_include(irp, (IrInstSrcCInclude *)instruction);
            break;
        case IrInstSrcIdCDefine:
            ir_print_c_define(irp, (IrInstSrcCDefine *)instruction);
            break;
        case IrInstSrcIdCUndef:
            ir_print_c_undef(irp, (IrInstSrcCUndef *)instruction);
            break;
        case IrInstSrcIdEmbedFile:
            ir_print_embed_file(irp, (IrInstSrcEmbedFile *)instruction);
            break;
        case IrInstSrcIdCmpxchg:
            ir_print_cmpxchg_src(irp, (IrInstSrcCmpxchg *)instruction);
            break;
        case IrInstSrcIdFence:
            ir_print_fence(irp, (IrInstSrcFence *)instruction);
            break;
        case IrInstSrcIdTruncate:
            ir_print_truncate(irp, (IrInstSrcTruncate *)instruction);
            break;
        case IrInstSrcIdIntCast:
            ir_print_int_cast(irp, (IrInstSrcIntCast *)instruction);
            break;
        case IrInstSrcIdFloatCast:
            ir_print_float_cast(irp, (IrInstSrcFloatCast *)instruction);
            break;
        case IrInstSrcIdErrSetCast:
            ir_print_err_set_cast(irp, (IrInstSrcErrSetCast *)instruction);
            break;
        case IrInstSrcIdIntToFloat:
            ir_print_int_to_float(irp, (IrInstSrcIntToFloat *)instruction);
            break;
        case IrInstSrcIdFloatToInt:
            ir_print_float_to_int(irp, (IrInstSrcFloatToInt *)instruction);
            break;
        case IrInstSrcIdBoolToInt:
            ir_print_bool_to_int(irp, (IrInstSrcBoolToInt *)instruction);
            break;
        case IrInstSrcIdVectorType:
            ir_print_vector_type(irp, (IrInstSrcVectorType *)instruction);
            break;
        case IrInstSrcIdShuffleVector:
            ir_print_shuffle_vector(irp, (IrInstSrcShuffleVector *)instruction);
            break;
        case IrInstSrcIdSplat:
            ir_print_splat_src(irp, (IrInstSrcSplat *)instruction);
            break;
        case IrInstSrcIdBoolNot:
            ir_print_bool_not(irp, (IrInstSrcBoolNot *)instruction);
            break;
        case IrInstSrcIdMemset:
            ir_print_memset(irp, (IrInstSrcMemset *)instruction);
            break;
        case IrInstSrcIdMemcpy:
            ir_print_memcpy(irp, (IrInstSrcMemcpy *)instruction);
            break;
        case IrInstSrcIdSlice:
            ir_print_slice_src(irp, (IrInstSrcSlice *)instruction);
            break;
        case IrInstSrcIdBreakpoint:
            ir_print_breakpoint(irp, (IrInstSrcBreakpoint *)instruction);
            break;
        case IrInstSrcIdReturnAddress:
            ir_print_return_address(irp, (IrInstSrcReturnAddress *)instruction);
            break;
        case IrInstSrcIdFrameAddress:
            ir_print_frame_address(irp, (IrInstSrcFrameAddress *)instruction);
            break;
        case IrInstSrcIdFrameHandle:
            ir_print_handle(irp, (IrInstSrcFrameHandle *)instruction);
            break;
        case IrInstSrcIdFrameType:
            ir_print_frame_type(irp, (IrInstSrcFrameType *)instruction);
            break;
        case IrInstSrcIdFrameSize:
            ir_print_frame_size_src(irp, (IrInstSrcFrameSize *)instruction);
            break;
        case IrInstSrcIdAlignOf:
            ir_print_align_of(irp, (IrInstSrcAlignOf *)instruction);
            break;
        case IrInstSrcIdOverflowOp:
            ir_print_overflow_op(irp, (IrInstSrcOverflowOp *)instruction);
            break;
        case IrInstSrcIdTestErr:
            ir_print_test_err_src(irp, (IrInstSrcTestErr *)instruction);
            break;
        case IrInstSrcIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (IrInstSrcUnwrapErrCode *)instruction);
            break;
        case IrInstSrcIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (IrInstSrcUnwrapErrPayload *)instruction);
            break;
        case IrInstSrcIdFnProto:
            ir_print_fn_proto(irp, (IrInstSrcFnProto *)instruction);
            break;
        case IrInstSrcIdTestComptime:
            ir_print_test_comptime(irp, (IrInstSrcTestComptime *)instruction);
            break;
        case IrInstSrcIdPtrCast:
            ir_print_ptr_cast_src(irp, (IrInstSrcPtrCast *)instruction);
            break;
        case IrInstSrcIdBitCast:
            ir_print_bit_cast_src(irp, (IrInstSrcBitCast *)instruction);
            break;
        case IrInstSrcIdPtrToInt:
            ir_print_ptr_to_int(irp, (IrInstSrcPtrToInt *)instruction);
            break;
        case IrInstSrcIdIntToPtr:
            ir_print_int_to_ptr(irp, (IrInstSrcIntToPtr *)instruction);
            break;
        case IrInstSrcIdIntToEnum:
            ir_print_int_to_enum(irp, (IrInstSrcIntToEnum *)instruction);
            break;
        case IrInstSrcIdIntToErr:
            ir_print_int_to_err(irp, (IrInstSrcIntToErr *)instruction);
            break;
        case IrInstSrcIdErrToInt:
            ir_print_err_to_int(irp, (IrInstSrcErrToInt *)instruction);
            break;
        case IrInstSrcIdCheckSwitchProngs:
            ir_print_check_switch_prongs(irp, (IrInstSrcCheckSwitchProngs *)instruction);
            break;
        case IrInstSrcIdCheckStatementIsVoid:
            ir_print_check_statement_is_void(irp, (IrInstSrcCheckStatementIsVoid *)instruction);
            break;
        case IrInstSrcIdTypeName:
            ir_print_type_name(irp, (IrInstSrcTypeName *)instruction);
            break;
        case IrInstSrcIdTagName:
            ir_print_tag_name(irp, (IrInstSrcTagName *)instruction);
            break;
        case IrInstSrcIdPtrType:
            ir_print_ptr_type(irp, (IrInstSrcPtrType *)instruction);
            break;
        case IrInstSrcIdDeclRef:
            ir_print_decl_ref(irp, (IrInstSrcDeclRef *)instruction);
            break;
        case IrInstSrcIdPanic:
            ir_print_panic(irp, (IrInstSrcPanic *)instruction);
            break;
        case IrInstSrcIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (IrInstSrcFieldParentPtr *)instruction);
            break;
        case IrInstSrcIdByteOffsetOf:
            ir_print_byte_offset_of(irp, (IrInstSrcByteOffsetOf *)instruction);
            break;
        case IrInstSrcIdBitOffsetOf:
            ir_print_bit_offset_of(irp, (IrInstSrcBitOffsetOf *)instruction);
            break;
        case IrInstSrcIdTypeInfo:
            ir_print_type_info(irp, (IrInstSrcTypeInfo *)instruction);
            break;
        case IrInstSrcIdType:
            ir_print_type(irp, (IrInstSrcType *)instruction);
            break;
        case IrInstSrcIdHasField:
            ir_print_has_field(irp, (IrInstSrcHasField *)instruction);
            break;
        case IrInstSrcIdSetEvalBranchQuota:
            ir_print_set_eval_branch_quota(irp, (IrInstSrcSetEvalBranchQuota *)instruction);
            break;
        case IrInstSrcIdAlignCast:
            ir_print_align_cast(irp, (IrInstSrcAlignCast *)instruction);
            break;
        case IrInstSrcIdImplicitCast:
            ir_print_implicit_cast(irp, (IrInstSrcImplicitCast *)instruction);
            break;
        case IrInstSrcIdResolveResult:
            ir_print_resolve_result(irp, (IrInstSrcResolveResult *)instruction);
            break;
        case IrInstSrcIdResetResult:
            ir_print_reset_result(irp, (IrInstSrcResetResult *)instruction);
            break;
        case IrInstSrcIdSetAlignStack:
            ir_print_set_align_stack(irp, (IrInstSrcSetAlignStack *)instruction);
            break;
        case IrInstSrcIdArgType:
            ir_print_arg_type(irp, (IrInstSrcArgType *)instruction);
            break;
        case IrInstSrcIdTagType:
            ir_print_enum_tag_type(irp, (IrInstSrcTagType *)instruction);
            break;
        case IrInstSrcIdExport:
            ir_print_export(irp, (IrInstSrcExport *)instruction);
            break;
        case IrInstSrcIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (IrInstSrcErrorReturnTrace *)instruction);
            break;
        case IrInstSrcIdErrorUnion:
            ir_print_error_union(irp, (IrInstSrcErrorUnion *)instruction);
            break;
        case IrInstSrcIdAtomicRmw:
            ir_print_atomic_rmw(irp, (IrInstSrcAtomicRmw *)instruction);
            break;
        case IrInstSrcIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (IrInstSrcSaveErrRetAddr *)instruction);
            break;
        case IrInstSrcIdAddImplicitReturnType:
            ir_print_add_implicit_return_type(irp, (IrInstSrcAddImplicitReturnType *)instruction);
            break;
        case IrInstSrcIdFloatOp:
            ir_print_float_op(irp, (IrInstSrcFloatOp *)instruction);
            break;
        case IrInstSrcIdMulAdd:
            ir_print_mul_add(irp, (IrInstSrcMulAdd *)instruction);
            break;
        case IrInstSrcIdAtomicLoad:
            ir_print_atomic_load(irp, (IrInstSrcAtomicLoad *)instruction);
            break;
        case IrInstSrcIdAtomicStore:
            ir_print_atomic_store(irp, (IrInstSrcAtomicStore *)instruction);
            break;
        case IrInstSrcIdEnumToInt:
            ir_print_enum_to_int(irp, (IrInstSrcEnumToInt *)instruction);
            break;
        case IrInstSrcIdCheckRuntimeScope:
            ir_print_check_runtime_scope(irp, (IrInstSrcCheckRuntimeScope *)instruction);
            break;
        case IrInstSrcIdHasDecl:
            ir_print_has_decl(irp, (IrInstSrcHasDecl *)instruction);
            break;
        case IrInstSrcIdUndeclaredIdent:
            ir_print_undeclared_ident(irp, (IrInstSrcUndeclaredIdent *)instruction);
            break;
        case IrInstSrcIdAlloca:
            ir_print_alloca_src(irp, (IrInstSrcAlloca *)instruction);
            break;
        case IrInstSrcIdEndExpr:
            ir_print_end_expr(irp, (IrInstSrcEndExpr *)instruction);
            break;
        case IrInstSrcIdUnionInitNamedField:
            ir_print_union_init_named_field(irp, (IrInstSrcUnionInitNamedField *)instruction);
            break;
        case IrInstSrcIdSuspendBegin:
            ir_print_suspend_begin(irp, (IrInstSrcSuspendBegin *)instruction);
            break;
        case IrInstSrcIdSuspendFinish:
            ir_print_suspend_finish(irp, (IrInstSrcSuspendFinish *)instruction);
            break;
        case IrInstSrcIdResume:
            ir_print_resume(irp, (IrInstSrcResume *)instruction);
            break;
        case IrInstSrcIdAwait:
            ir_print_await_src(irp, (IrInstSrcAwait *)instruction);
            break;
        case IrInstSrcIdSpillBegin:
            ir_print_spill_begin(irp, (IrInstSrcSpillBegin *)instruction);
            break;
        case IrInstSrcIdSpillEnd:
            ir_print_spill_end(irp, (IrInstSrcSpillEnd *)instruction);
            break;
        case IrInstSrcIdClz:
            ir_print_clz(irp, (IrInstSrcClz *)instruction);
            break;
        case IrInstSrcIdWasmMemorySize:
            ir_print_wasm_memory_size(irp, (IrInstSrcWasmMemorySize *)instruction);
            break;
        case IrInstSrcIdWasmMemoryGrow:
            ir_print_wasm_memory_grow(irp, (IrInstSrcWasmMemoryGrow *)instruction);
            break;
        case IrInstSrcIdSrc:
            ir_print_builtin_src(irp, (IrInstSrcSrc *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

static void ir_print_inst_gen(IrPrintGen *irp, IrInstGen *instruction, bool trailing) {
    ir_print_prefix_gen(irp, instruction, trailing);
    switch (instruction->id) {
        case IrInstGenIdInvalid:
            zig_unreachable();
        case IrInstGenIdReturn:
            ir_print_return_gen(irp, (IrInstGenReturn *)instruction);
            break;
        case IrInstGenIdConst:
            ir_print_const(irp, (IrInstGenConst *)instruction);
            break;
        case IrInstGenIdBinOp:
            ir_print_bin_op(irp, (IrInstGenBinOp *)instruction);
            break;
        case IrInstGenIdDeclVar:
            ir_print_decl_var_gen(irp, (IrInstGenDeclVar *)instruction);
            break;
        case IrInstGenIdCast:
            ir_print_cast(irp, (IrInstGenCast *)instruction);
            break;
        case IrInstGenIdCall:
            ir_print_call_gen(irp, (IrInstGenCall *)instruction);
            break;
        case IrInstGenIdCondBr:
            ir_print_cond_br(irp, (IrInstGenCondBr *)instruction);
            break;
        case IrInstGenIdBr:
            ir_print_br(irp, (IrInstGenBr *)instruction);
            break;
        case IrInstGenIdPhi:
            ir_print_phi(irp, (IrInstGenPhi *)instruction);
            break;
        case IrInstGenIdUnreachable:
            ir_print_unreachable(irp, (IrInstGenUnreachable *)instruction);
            break;
        case IrInstGenIdElemPtr:
            ir_print_elem_ptr(irp, (IrInstGenElemPtr *)instruction);
            break;
        case IrInstGenIdVarPtr:
            ir_print_var_ptr(irp, (IrInstGenVarPtr *)instruction);
            break;
        case IrInstGenIdReturnPtr:
            ir_print_return_ptr(irp, (IrInstGenReturnPtr *)instruction);
            break;
        case IrInstGenIdLoadPtr:
            ir_print_load_ptr_gen(irp, (IrInstGenLoadPtr *)instruction);
            break;
        case IrInstGenIdStorePtr:
            ir_print_store_ptr(irp, (IrInstGenStorePtr *)instruction);
            break;
        case IrInstGenIdStructFieldPtr:
            ir_print_struct_field_ptr(irp, (IrInstGenStructFieldPtr *)instruction);
            break;
        case IrInstGenIdUnionFieldPtr:
            ir_print_union_field_ptr(irp, (IrInstGenUnionFieldPtr *)instruction);
            break;
        case IrInstGenIdAsm:
            ir_print_asm_gen(irp, (IrInstGenAsm *)instruction);
            break;
        case IrInstGenIdTestNonNull:
            ir_print_test_non_null(irp, (IrInstGenTestNonNull *)instruction);
            break;
        case IrInstGenIdOptionalUnwrapPtr:
            ir_print_optional_unwrap_ptr(irp, (IrInstGenOptionalUnwrapPtr *)instruction);
            break;
        case IrInstGenIdPopCount:
            ir_print_pop_count(irp, (IrInstGenPopCount *)instruction);
            break;
        case IrInstGenIdClz:
            ir_print_clz(irp, (IrInstGenClz *)instruction);
            break;
        case IrInstGenIdCtz:
            ir_print_ctz(irp, (IrInstGenCtz *)instruction);
            break;
        case IrInstGenIdBswap:
            ir_print_bswap(irp, (IrInstGenBswap *)instruction);
            break;
        case IrInstGenIdBitReverse:
            ir_print_bit_reverse(irp, (IrInstGenBitReverse *)instruction);
            break;
        case IrInstGenIdSwitchBr:
            ir_print_switch_br(irp, (IrInstGenSwitchBr *)instruction);
            break;
        case IrInstGenIdUnionTag:
            ir_print_union_tag(irp, (IrInstGenUnionTag *)instruction);
            break;
        case IrInstGenIdRef:
            ir_print_ref_gen(irp, (IrInstGenRef *)instruction);
            break;
        case IrInstGenIdErrName:
            ir_print_err_name(irp, (IrInstGenErrName *)instruction);
            break;
        case IrInstGenIdCmpxchg:
            ir_print_cmpxchg_gen(irp, (IrInstGenCmpxchg *)instruction);
            break;
        case IrInstGenIdFence:
            ir_print_fence(irp, (IrInstGenFence *)instruction);
            break;
        case IrInstGenIdTruncate:
            ir_print_truncate(irp, (IrInstGenTruncate *)instruction);
            break;
        case IrInstGenIdShuffleVector:
            ir_print_shuffle_vector(irp, (IrInstGenShuffleVector *)instruction);
            break;
        case IrInstGenIdSplat:
            ir_print_splat_gen(irp, (IrInstGenSplat *)instruction);
            break;
        case IrInstGenIdBoolNot:
            ir_print_bool_not(irp, (IrInstGenBoolNot *)instruction);
            break;
        case IrInstGenIdMemset:
            ir_print_memset(irp, (IrInstGenMemset *)instruction);
            break;
        case IrInstGenIdMemcpy:
            ir_print_memcpy(irp, (IrInstGenMemcpy *)instruction);
            break;
        case IrInstGenIdSlice:
            ir_print_slice_gen(irp, (IrInstGenSlice *)instruction);
            break;
        case IrInstGenIdBreakpoint:
            ir_print_breakpoint(irp, (IrInstGenBreakpoint *)instruction);
            break;
        case IrInstGenIdReturnAddress:
            ir_print_return_address(irp, (IrInstGenReturnAddress *)instruction);
            break;
        case IrInstGenIdFrameAddress:
            ir_print_frame_address(irp, (IrInstGenFrameAddress *)instruction);
            break;
        case IrInstGenIdFrameHandle:
            ir_print_handle(irp, (IrInstGenFrameHandle *)instruction);
            break;
        case IrInstGenIdFrameSize:
            ir_print_frame_size_gen(irp, (IrInstGenFrameSize *)instruction);
            break;
        case IrInstGenIdOverflowOp:
            ir_print_overflow_op(irp, (IrInstGenOverflowOp *)instruction);
            break;
        case IrInstGenIdTestErr:
            ir_print_test_err_gen(irp, (IrInstGenTestErr *)instruction);
            break;
        case IrInstGenIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (IrInstGenUnwrapErrCode *)instruction);
            break;
        case IrInstGenIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (IrInstGenUnwrapErrPayload *)instruction);
            break;
        case IrInstGenIdOptionalWrap:
            ir_print_optional_wrap(irp, (IrInstGenOptionalWrap *)instruction);
            break;
        case IrInstGenIdErrWrapCode:
            ir_print_err_wrap_code(irp, (IrInstGenErrWrapCode *)instruction);
            break;
        case IrInstGenIdErrWrapPayload:
            ir_print_err_wrap_payload(irp, (IrInstGenErrWrapPayload *)instruction);
            break;
        case IrInstGenIdPtrCast:
            ir_print_ptr_cast_gen(irp, (IrInstGenPtrCast *)instruction);
            break;
        case IrInstGenIdBitCast:
            ir_print_bit_cast_gen(irp, (IrInstGenBitCast *)instruction);
            break;
        case IrInstGenIdWidenOrShorten:
            ir_print_widen_or_shorten(irp, (IrInstGenWidenOrShorten *)instruction);
            break;
        case IrInstGenIdPtrToInt:
            ir_print_ptr_to_int(irp, (IrInstGenPtrToInt *)instruction);
            break;
        case IrInstGenIdIntToPtr:
            ir_print_int_to_ptr(irp, (IrInstGenIntToPtr *)instruction);
            break;
        case IrInstGenIdIntToEnum:
            ir_print_int_to_enum(irp, (IrInstGenIntToEnum *)instruction);
            break;
        case IrInstGenIdIntToErr:
            ir_print_int_to_err(irp, (IrInstGenIntToErr *)instruction);
            break;
        case IrInstGenIdErrToInt:
            ir_print_err_to_int(irp, (IrInstGenErrToInt *)instruction);
            break;
        case IrInstGenIdTagName:
            ir_print_tag_name(irp, (IrInstGenTagName *)instruction);
            break;
        case IrInstGenIdPanic:
            ir_print_panic(irp, (IrInstGenPanic *)instruction);
            break;
        case IrInstGenIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (IrInstGenFieldParentPtr *)instruction);
            break;
        case IrInstGenIdAlignCast:
            ir_print_align_cast(irp, (IrInstGenAlignCast *)instruction);
            break;
        case IrInstGenIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (IrInstGenErrorReturnTrace *)instruction);
            break;
        case IrInstGenIdAtomicRmw:
            ir_print_atomic_rmw(irp, (IrInstGenAtomicRmw *)instruction);
            break;
        case IrInstGenIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (IrInstGenSaveErrRetAddr *)instruction);
            break;
        case IrInstGenIdFloatOp:
            ir_print_float_op(irp, (IrInstGenFloatOp *)instruction);
            break;
        case IrInstGenIdMulAdd:
            ir_print_mul_add(irp, (IrInstGenMulAdd *)instruction);
            break;
        case IrInstGenIdAtomicLoad:
            ir_print_atomic_load(irp, (IrInstGenAtomicLoad *)instruction);
            break;
        case IrInstGenIdAtomicStore:
            ir_print_atomic_store(irp, (IrInstGenAtomicStore *)instruction);
            break;
        case IrInstGenIdArrayToVector:
            ir_print_array_to_vector(irp, (IrInstGenArrayToVector *)instruction);
            break;
        case IrInstGenIdVectorToArray:
            ir_print_vector_to_array(irp, (IrInstGenVectorToArray *)instruction);
            break;
        case IrInstGenIdPtrOfArrayToSlice:
            ir_print_ptr_of_array_to_slice(irp, (IrInstGenPtrOfArrayToSlice *)instruction);
            break;
        case IrInstGenIdAssertZero:
            ir_print_assert_zero(irp, (IrInstGenAssertZero *)instruction);
            break;
        case IrInstGenIdAssertNonNull:
            ir_print_assert_non_null(irp, (IrInstGenAssertNonNull *)instruction);
            break;
        case IrInstGenIdAlloca:
            ir_print_alloca_gen(irp, (IrInstGenAlloca *)instruction);
            break;
        case IrInstGenIdSuspendBegin:
            ir_print_suspend_begin(irp, (IrInstGenSuspendBegin *)instruction);
            break;
        case IrInstGenIdSuspendFinish:
            ir_print_suspend_finish(irp, (IrInstGenSuspendFinish *)instruction);
            break;
        case IrInstGenIdResume:
            ir_print_resume(irp, (IrInstGenResume *)instruction);
            break;
        case IrInstGenIdAwait:
            ir_print_await_gen(irp, (IrInstGenAwait *)instruction);
            break;
        case IrInstGenIdSpillBegin:
            ir_print_spill_begin(irp, (IrInstGenSpillBegin *)instruction);
            break;
        case IrInstGenIdSpillEnd:
            ir_print_spill_end(irp, (IrInstGenSpillEnd *)instruction);
            break;
        case IrInstGenIdVectorExtractElem:
            ir_print_vector_extract_elem(irp, (IrInstGenVectorExtractElem *)instruction);
            break;
        case IrInstGenIdVectorStoreElem:
            ir_print_vector_store_elem(irp, (IrInstGenVectorStoreElem *)instruction);
            break;
        case IrInstGenIdBinaryNot:
            ir_print_binary_not(irp, (IrInstGenBinaryNot *)instruction);
            break;
        case IrInstGenIdNegation:
            ir_print_negation(irp, (IrInstGenNegation *)instruction);
            break;
        case IrInstGenIdNegationWrapping:
            ir_print_negation_wrapping(irp, (IrInstGenNegationWrapping *)instruction);
            break;
        case IrInstGenIdWasmMemorySize:
            ir_print_wasm_memory_size(irp, (IrInstGenWasmMemorySize *)instruction);
            break;
        case IrInstGenIdWasmMemoryGrow:
            ir_print_wasm_memory_grow(irp, (IrInstGenWasmMemoryGrow *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

static void irp_print_basic_block_src(IrPrintSrc *irp, IrBasicBlockSrc *current_block) {
    fprintf(irp->f, "%s_%" PRIu32 ":\n", current_block->name_hint, current_block->debug_id);
    for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
        IrInstSrc *instruction = current_block->instruction_list.at(instr_i);
        ir_print_inst_src(irp, instruction, false);
    }
}

static void irp_print_basic_block_gen(IrPrintGen *irp, IrBasicBlockGen *current_block) {
    fprintf(irp->f, "%s_%" PRIu32 ":\n", current_block->name_hint, current_block->debug_id);
    for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
        IrInstGen *instruction = current_block->instruction_list.at(instr_i);
        irp->printed.put(instruction, 0);
        irp->pending.clear();
        ir_print_inst_gen(irp, instruction, false);
        for (size_t j = 0; j < irp->pending.length; ++j)
            ir_print_inst_gen(irp, irp->pending.at(j), true);
    }
}

void ir_print_basic_block_src(CodeGen *codegen, FILE *f, IrBasicBlockSrc *bb, int indent_size) {
    IrPrintSrc ir_print = {};
    ir_print.codegen = codegen;
    ir_print.f = f;
    ir_print.indent = indent_size;
    ir_print.indent_size = indent_size;

    irp_print_basic_block_src(&ir_print, bb);
}

void ir_print_basic_block_gen(CodeGen *codegen, FILE *f, IrBasicBlockGen *bb, int indent_size) {
    IrPrintGen ir_print = {};
    ir_print.codegen = codegen;
    ir_print.f = f;
    ir_print.indent = indent_size;
    ir_print.indent_size = indent_size;
    ir_print.printed = {};
    ir_print.printed.init(64);
    ir_print.pending = {};

    irp_print_basic_block_gen(&ir_print, bb);

    ir_print.pending.deinit();
    ir_print.printed.deinit();
}

void ir_print_src(CodeGen *codegen, FILE *f, IrExecutableSrc *executable, int indent_size) {
    IrPrintSrc ir_print = {};
    IrPrintSrc *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    for (size_t bb_i = 0; bb_i < executable->basic_block_list.length; bb_i += 1) {
        irp_print_basic_block_src(irp, executable->basic_block_list.at(bb_i));
    }
}

void ir_print_gen(CodeGen *codegen, FILE *f, IrExecutableGen *executable, int indent_size) {
    IrPrintGen ir_print = {};
    IrPrintGen *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;
    irp->printed = {};
    irp->printed.init(64);
    irp->pending = {};

    for (size_t bb_i = 0; bb_i < executable->basic_block_list.length; bb_i += 1) {
        irp_print_basic_block_gen(irp, executable->basic_block_list.at(bb_i));
    }

    irp->pending.deinit();
    irp->printed.deinit();
}

void ir_print_inst_src(CodeGen *codegen, FILE *f, IrInstSrc *instruction, int indent_size) {
    IrPrintSrc ir_print = {};
    IrPrintSrc *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    ir_print_inst_src(irp, instruction, false);
}

void ir_print_inst_gen(CodeGen *codegen, FILE *f, IrInstGen *instruction, int indent_size) {
    IrPrintGen ir_print = {};
    IrPrintGen *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;
    irp->printed = {};
    irp->printed.init(4);
    irp->pending = {};

    ir_print_inst_gen(irp, instruction, false);
}
