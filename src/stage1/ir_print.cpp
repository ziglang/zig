/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "all_types.hpp"
#include "analyze.hpp"
#include "ir.hpp"
#include "astgen.hpp"
#include "ir_print.hpp"
#include "os.hpp"

static uint32_t hash_inst_src_ptr(Stage1ZirInst* instruction) {
    return (uint32_t)(uintptr_t)instruction;
}

static uint32_t hash_inst_gen_ptr(Stage1AirInst* instruction) {
    return (uint32_t)(uintptr_t)instruction;
}

static bool inst_src_ptr_eql(Stage1ZirInst* a, Stage1ZirInst* b) {
    return a == b;
}

static bool inst_gen_ptr_eql(Stage1AirInst* a, Stage1AirInst* b) {
    return a == b;
}

using InstSetSrc = HashMap<Stage1ZirInst*, uint8_t, hash_inst_src_ptr, inst_src_ptr_eql>;
using InstSetGen = HashMap<Stage1AirInst*, uint8_t, hash_inst_gen_ptr, inst_gen_ptr_eql>;
using InstListSrc = ZigList<Stage1ZirInst*>;
using InstListGen = ZigList<Stage1AirInst*>;

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

static void ir_print_other_inst_src(IrPrintSrc *irp, Stage1ZirInst *inst);
static void ir_print_other_inst_gen(IrPrintGen *irp, Stage1AirInst *inst);

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

const char* ir_inst_src_type_str(Stage1ZirInstId id) {
    switch (id) {
        case Stage1ZirInstIdInvalid:
            return "SrcInvalid";
        case Stage1ZirInstIdShuffleVector:
            return "SrcShuffle";
        case Stage1ZirInstIdSplat:
            return "SrcSplat";
        case Stage1ZirInstIdDeclVar:
            return "SrcDeclVar";
        case Stage1ZirInstIdBr:
            return "SrcBr";
        case Stage1ZirInstIdCondBr:
            return "SrcCondBr";
        case Stage1ZirInstIdSwitchBr:
            return "SrcSwitchBr";
        case Stage1ZirInstIdSwitchVar:
            return "SrcSwitchVar";
        case Stage1ZirInstIdSwitchElseVar:
            return "SrcSwitchElseVar";
        case Stage1ZirInstIdSwitchTarget:
            return "SrcSwitchTarget";
        case Stage1ZirInstIdPhi:
            return "SrcPhi";
        case Stage1ZirInstIdUnOp:
            return "SrcUnOp";
        case Stage1ZirInstIdBinOp:
            return "SrcBinOp";
        case Stage1ZirInstIdMergeErrSets:
            return "SrcMergeErrSets";
        case Stage1ZirInstIdLoadPtr:
            return "SrcLoadPtr";
        case Stage1ZirInstIdStorePtr:
            return "SrcStorePtr";
        case Stage1ZirInstIdFieldPtr:
            return "SrcFieldPtr";
        case Stage1ZirInstIdElemPtr:
            return "SrcElemPtr";
        case Stage1ZirInstIdVarPtr:
            return "SrcVarPtr";
        case Stage1ZirInstIdCallExtra:
            return "SrcCallExtra";
        case Stage1ZirInstIdAsyncCallExtra:
            return "SrcAsyncCallExtra";
        case Stage1ZirInstIdCall:
            return "SrcCall";
        case Stage1ZirInstIdCallArgs:
            return "SrcCallArgs";
        case Stage1ZirInstIdConst:
            return "SrcConst";
        case Stage1ZirInstIdReturn:
            return "SrcReturn";
        case Stage1ZirInstIdContainerInitList:
            return "SrcContainerInitList";
        case Stage1ZirInstIdContainerInitFields:
            return "SrcContainerInitFields";
        case Stage1ZirInstIdUnreachable:
            return "SrcUnreachable";
        case Stage1ZirInstIdTypeOf:
            return "SrcTypeOf";
        case Stage1ZirInstIdSetCold:
            return "SrcSetCold";
        case Stage1ZirInstIdSetRuntimeSafety:
            return "SrcSetRuntimeSafety";
        case Stage1ZirInstIdSetFloatMode:
            return "SrcSetFloatMode";
        case Stage1ZirInstIdArrayType:
            return "SrcArrayType";
        case Stage1ZirInstIdAnyFrameType:
            return "SrcAnyFrameType";
        case Stage1ZirInstIdSliceType:
            return "SrcSliceType";
        case Stage1ZirInstIdAsm:
            return "SrcAsm";
        case Stage1ZirInstIdSizeOf:
            return "SrcSizeOf";
        case Stage1ZirInstIdTestNonNull:
            return "SrcTestNonNull";
        case Stage1ZirInstIdOptionalUnwrapPtr:
            return "SrcOptionalUnwrapPtr";
        case Stage1ZirInstIdClz:
            return "SrcClz";
        case Stage1ZirInstIdCtz:
            return "SrcCtz";
        case Stage1ZirInstIdPopCount:
            return "SrcPopCount";
        case Stage1ZirInstIdBswap:
            return "SrcBswap";
        case Stage1ZirInstIdBitReverse:
            return "SrcBitReverse";
        case Stage1ZirInstIdImport:
            return "SrcImport";
        case Stage1ZirInstIdCImport:
            return "SrcCImport";
        case Stage1ZirInstIdCInclude:
            return "SrcCInclude";
        case Stage1ZirInstIdCDefine:
            return "SrcCDefine";
        case Stage1ZirInstIdCUndef:
            return "SrcCUndef";
        case Stage1ZirInstIdRef:
            return "SrcRef";
        case Stage1ZirInstIdCompileErr:
            return "SrcCompileErr";
        case Stage1ZirInstIdCompileLog:
            return "SrcCompileLog";
        case Stage1ZirInstIdErrName:
            return "SrcErrName";
        case Stage1ZirInstIdEmbedFile:
            return "SrcEmbedFile";
        case Stage1ZirInstIdCmpxchg:
            return "SrcCmpxchg";
        case Stage1ZirInstIdFence:
            return "SrcFence";
        case Stage1ZirInstIdReduce:
            return "SrcReduce";
        case Stage1ZirInstIdTruncate:
            return "SrcTruncate";
        case Stage1ZirInstIdIntCast:
            return "SrcIntCast";
        case Stage1ZirInstIdFloatCast:
            return "SrcFloatCast";
        case Stage1ZirInstIdIntToFloat:
            return "SrcIntToFloat";
        case Stage1ZirInstIdFloatToInt:
            return "SrcFloatToInt";
        case Stage1ZirInstIdBoolToInt:
            return "SrcBoolToInt";
        case Stage1ZirInstIdVectorType:
            return "SrcVectorType";
        case Stage1ZirInstIdBoolNot:
            return "SrcBoolNot";
        case Stage1ZirInstIdMemset:
            return "SrcMemset";
        case Stage1ZirInstIdMemcpy:
            return "SrcMemcpy";
        case Stage1ZirInstIdSlice:
            return "SrcSlice";
        case Stage1ZirInstIdBreakpoint:
            return "SrcBreakpoint";
        case Stage1ZirInstIdReturnAddress:
            return "SrcReturnAddress";
        case Stage1ZirInstIdFrameAddress:
            return "SrcFrameAddress";
        case Stage1ZirInstIdFrameHandle:
            return "SrcFrameHandle";
        case Stage1ZirInstIdFrameType:
            return "SrcFrameType";
        case Stage1ZirInstIdFrameSize:
            return "SrcFrameSize";
        case Stage1ZirInstIdAlignOf:
            return "SrcAlignOf";
        case Stage1ZirInstIdOverflowOp:
            return "SrcOverflowOp";
        case Stage1ZirInstIdTestErr:
            return "SrcTestErr";
        case Stage1ZirInstIdMulAdd:
            return "SrcMulAdd";
        case Stage1ZirInstIdFloatOp:
            return "SrcFloatOp";
        case Stage1ZirInstIdUnwrapErrCode:
            return "SrcUnwrapErrCode";
        case Stage1ZirInstIdUnwrapErrPayload:
            return "SrcUnwrapErrPayload";
        case Stage1ZirInstIdFnProto:
            return "SrcFnProto";
        case Stage1ZirInstIdTestComptime:
            return "SrcTestComptime";
        case Stage1ZirInstIdPtrCast:
            return "SrcPtrCast";
        case Stage1ZirInstIdBitCast:
            return "SrcBitCast";
        case Stage1ZirInstIdIntToPtr:
            return "SrcIntToPtr";
        case Stage1ZirInstIdPtrToInt:
            return "SrcPtrToInt";
        case Stage1ZirInstIdIntToEnum:
            return "SrcIntToEnum";
        case Stage1ZirInstIdEnumToInt:
            return "SrcEnumToInt";
        case Stage1ZirInstIdIntToErr:
            return "SrcIntToErr";
        case Stage1ZirInstIdErrToInt:
            return "SrcErrToInt";
        case Stage1ZirInstIdCheckSwitchProngsUnderNo:
            return "SrcCheckSwitchProngsUnderNo";
        case Stage1ZirInstIdCheckSwitchProngsUnderYes:
            return "SrcCheckSwitchProngsUnderYes";
        case Stage1ZirInstIdCheckStatementIsVoid:
            return "SrcCheckStatementIsVoid";
        case Stage1ZirInstIdTypeName:
            return "SrcTypeName";
        case Stage1ZirInstIdDeclRef:
            return "SrcDeclRef";
        case Stage1ZirInstIdPanic:
            return "SrcPanic";
        case Stage1ZirInstIdTagName:
            return "SrcTagName";
        case Stage1ZirInstIdFieldParentPtr:
            return "SrcFieldParentPtr";
        case Stage1ZirInstIdOffsetOf:
            return "SrcOffsetOf";
        case Stage1ZirInstIdBitOffsetOf:
            return "SrcBitOffsetOf";
        case Stage1ZirInstIdTypeInfo:
            return "SrcTypeInfo";
        case Stage1ZirInstIdType:
            return "SrcType";
        case Stage1ZirInstIdHasField:
            return "SrcHasField";
        case Stage1ZirInstIdSetEvalBranchQuota:
            return "SrcSetEvalBranchQuota";
        case Stage1ZirInstIdPtrType:
            return "SrcPtrType";
        case Stage1ZirInstIdPtrTypeSimple:
            return "SrcPtrTypeSimple";
        case Stage1ZirInstIdPtrTypeSimpleConst:
            return "SrcPtrTypeSimpleConst";
        case Stage1ZirInstIdAlignCast:
            return "SrcAlignCast";
        case Stage1ZirInstIdImplicitCast:
            return "SrcImplicitCast";
        case Stage1ZirInstIdResolveResult:
            return "SrcResolveResult";
        case Stage1ZirInstIdResetResult:
            return "SrcResetResult";
        case Stage1ZirInstIdSetAlignStack:
            return "SrcSetAlignStack";
        case Stage1ZirInstIdArgTypeAllowVarFalse:
            return "SrcArgTypeAllowVarFalse";
        case Stage1ZirInstIdArgTypeAllowVarTrue:
            return "SrcArgTypeAllowVarTrue";
        case Stage1ZirInstIdExport:
            return "SrcExport";
        case Stage1ZirInstIdExtern:
            return "SrcExtern";
        case Stage1ZirInstIdErrorReturnTrace:
            return "SrcErrorReturnTrace";
        case Stage1ZirInstIdErrorUnion:
            return "SrcErrorUnion";
        case Stage1ZirInstIdAtomicRmw:
            return "SrcAtomicRmw";
        case Stage1ZirInstIdAtomicLoad:
            return "SrcAtomicLoad";
        case Stage1ZirInstIdAtomicStore:
            return "SrcAtomicStore";
        case Stage1ZirInstIdSaveErrRetAddr:
            return "SrcSaveErrRetAddr";
        case Stage1ZirInstIdAddImplicitReturnType:
            return "SrcAddImplicitReturnType";
        case Stage1ZirInstIdErrSetCast:
            return "SrcErrSetCast";
        case Stage1ZirInstIdCheckRuntimeScope:
            return "SrcCheckRuntimeScope";
        case Stage1ZirInstIdHasDecl:
            return "SrcHasDecl";
        case Stage1ZirInstIdUndeclaredIdent:
            return "SrcUndeclaredIdent";
        case Stage1ZirInstIdAlloca:
            return "SrcAlloca";
        case Stage1ZirInstIdEndExpr:
            return "SrcEndExpr";
        case Stage1ZirInstIdUnionInitNamedField:
            return "SrcUnionInitNamedField";
        case Stage1ZirInstIdSuspendBegin:
            return "SrcSuspendBegin";
        case Stage1ZirInstIdSuspendFinish:
            return "SrcSuspendFinish";
        case Stage1ZirInstIdAwait:
            return "SrcAwaitSr";
        case Stage1ZirInstIdResume:
            return "SrcResume";
        case Stage1ZirInstIdSpillBegin:
            return "SrcSpillBegin";
        case Stage1ZirInstIdSpillEnd:
            return "SrcSpillEnd";
        case Stage1ZirInstIdWasmMemorySize:
            return "SrcWasmMemorySize";
        case Stage1ZirInstIdWasmMemoryGrow:
            return "SrcWasmMemoryGrow";
        case Stage1ZirInstIdSrc:
            return "SrcSrc";
    }
    zig_unreachable();
}

const char* ir_inst_gen_type_str(Stage1AirInstId id) {
    switch (id) {
        case Stage1AirInstIdInvalid:
            return "GenInvalid";
        case Stage1AirInstIdShuffleVector:
            return "GenShuffle";
        case Stage1AirInstIdSplat:
            return "GenSplat";
        case Stage1AirInstIdDeclVar:
            return "GenDeclVar";
        case Stage1AirInstIdBr:
            return "GenBr";
        case Stage1AirInstIdCondBr:
            return "GenCondBr";
        case Stage1AirInstIdSwitchBr:
            return "GenSwitchBr";
        case Stage1AirInstIdPhi:
            return "GenPhi";
        case Stage1AirInstIdBinOp:
            return "GenBinOp";
        case Stage1AirInstIdLoadPtr:
            return "GenLoadPtr";
        case Stage1AirInstIdStorePtr:
            return "GenStorePtr";
        case Stage1AirInstIdVectorStoreElem:
            return "GenVectorStoreElem";
        case Stage1AirInstIdStructFieldPtr:
            return "GenStructFieldPtr";
        case Stage1AirInstIdUnionFieldPtr:
            return "GenUnionFieldPtr";
        case Stage1AirInstIdElemPtr:
            return "GenElemPtr";
        case Stage1AirInstIdVarPtr:
            return "GenVarPtr";
        case Stage1AirInstIdReturnPtr:
            return "GenReturnPtr";
        case Stage1AirInstIdCall:
            return "GenCall";
        case Stage1AirInstIdConst:
            return "GenConst";
        case Stage1AirInstIdReturn:
            return "GenReturn";
        case Stage1AirInstIdCast:
            return "GenCast";
        case Stage1AirInstIdUnreachable:
            return "GenUnreachable";
        case Stage1AirInstIdAsm:
            return "GenAsm";
        case Stage1AirInstIdTestNonNull:
            return "GenTestNonNull";
        case Stage1AirInstIdOptionalUnwrapPtr:
            return "GenOptionalUnwrapPtr";
        case Stage1AirInstIdOptionalWrap:
            return "GenOptionalWrap";
        case Stage1AirInstIdUnionTag:
            return "GenUnionTag";
        case Stage1AirInstIdClz:
            return "GenClz";
        case Stage1AirInstIdCtz:
            return "GenCtz";
        case Stage1AirInstIdPopCount:
            return "GenPopCount";
        case Stage1AirInstIdBswap:
            return "GenBswap";
        case Stage1AirInstIdBitReverse:
            return "GenBitReverse";
        case Stage1AirInstIdRef:
            return "GenRef";
        case Stage1AirInstIdErrName:
            return "GenErrName";
        case Stage1AirInstIdCmpxchg:
            return "GenCmpxchg";
        case Stage1AirInstIdFence:
            return "GenFence";
        case Stage1AirInstIdReduce:
            return "GenReduce";
        case Stage1AirInstIdTruncate:
            return "GenTruncate";
        case Stage1AirInstIdBoolNot:
            return "GenBoolNot";
        case Stage1AirInstIdMemset:
            return "GenMemset";
        case Stage1AirInstIdMemcpy:
            return "GenMemcpy";
        case Stage1AirInstIdSlice:
            return "GenSlice";
        case Stage1AirInstIdBreakpoint:
            return "GenBreakpoint";
        case Stage1AirInstIdReturnAddress:
            return "GenReturnAddress";
        case Stage1AirInstIdFrameAddress:
            return "GenFrameAddress";
        case Stage1AirInstIdFrameHandle:
            return "GenFrameHandle";
        case Stage1AirInstIdFrameSize:
            return "GenFrameSize";
        case Stage1AirInstIdOverflowOp:
            return "GenOverflowOp";
        case Stage1AirInstIdTestErr:
            return "GenTestErr";
        case Stage1AirInstIdMulAdd:
            return "GenMulAdd";
        case Stage1AirInstIdFloatOp:
            return "GenFloatOp";
        case Stage1AirInstIdUnwrapErrCode:
            return "GenUnwrapErrCode";
        case Stage1AirInstIdUnwrapErrPayload:
            return "GenUnwrapErrPayload";
        case Stage1AirInstIdErrWrapCode:
            return "GenErrWrapCode";
        case Stage1AirInstIdErrWrapPayload:
            return "GenErrWrapPayload";
        case Stage1AirInstIdPtrCast:
            return "GenPtrCast";
        case Stage1AirInstIdBitCast:
            return "GenBitCast";
        case Stage1AirInstIdWidenOrShorten:
            return "GenWidenOrShorten";
        case Stage1AirInstIdIntToPtr:
            return "GenIntToPtr";
        case Stage1AirInstIdPtrToInt:
            return "GenPtrToInt";
        case Stage1AirInstIdIntToEnum:
            return "GenIntToEnum";
        case Stage1AirInstIdIntToErr:
            return "GenIntToErr";
        case Stage1AirInstIdErrToInt:
            return "GenErrToInt";
        case Stage1AirInstIdPanic:
            return "GenPanic";
        case Stage1AirInstIdTagName:
            return "GenTagName";
        case Stage1AirInstIdFieldParentPtr:
            return "GenFieldParentPtr";
        case Stage1AirInstIdAlignCast:
            return "GenAlignCast";
        case Stage1AirInstIdErrorReturnTrace:
            return "GenErrorReturnTrace";
        case Stage1AirInstIdAtomicRmw:
            return "GenAtomicRmw";
        case Stage1AirInstIdAtomicLoad:
            return "GenAtomicLoad";
        case Stage1AirInstIdAtomicStore:
            return "GenAtomicStore";
        case Stage1AirInstIdSaveErrRetAddr:
            return "GenSaveErrRetAddr";
        case Stage1AirInstIdVectorToArray:
            return "GenVectorToArray";
        case Stage1AirInstIdArrayToVector:
            return "GenArrayToVector";
        case Stage1AirInstIdAssertZero:
            return "GenAssertZero";
        case Stage1AirInstIdAssertNonNull:
            return "GenAssertNonNull";
        case Stage1AirInstIdAlloca:
            return "GenAlloca";
        case Stage1AirInstIdPtrOfArrayToSlice:
            return "GenPtrOfArrayToSlice";
        case Stage1AirInstIdSuspendBegin:
            return "GenSuspendBegin";
        case Stage1AirInstIdSuspendFinish:
            return "GenSuspendFinish";
        case Stage1AirInstIdAwait:
            return "GenAwait";
        case Stage1AirInstIdResume:
            return "GenResume";
        case Stage1AirInstIdSpillBegin:
            return "GenSpillBegin";
        case Stage1AirInstIdSpillEnd:
            return "GenSpillEnd";
        case Stage1AirInstIdVectorExtractElem:
            return "GenVectorExtractElem";
        case Stage1AirInstIdBinaryNot:
            return "GenBinaryNot";
        case Stage1AirInstIdNegation:
            return "GenNegation";
        case Stage1AirInstIdWasmMemorySize:
            return "GenWasmMemorySize";
        case Stage1AirInstIdWasmMemoryGrow:
            return "GenWasmMemoryGrow";
        case Stage1AirInstIdExtern:
            return "GenExtrern";
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

static void ir_print_prefix_src(IrPrintSrc *irp, Stage1ZirInst *instruction, bool trailing) {
    ir_print_indent_src(irp);
    const char mark = trailing ? ':' : '#';
    const char *type_name;
    if (instruction->id == Stage1ZirInstIdConst) {
        type_name = buf_ptr(&reinterpret_cast<Stage1ZirInstConst *>(instruction)->value->type->name);
    } else {
        type_name = "(unknown)";
    }
    const char *ref_count = ir_inst_src_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%" PRIu32 "", instruction->ref_count));
    fprintf(irp->f, "%c%-3" PRIu32 "| %-22s| %-12s| %-2s| ", mark, instruction->debug_id,
        ir_inst_src_type_str(instruction->id), type_name, ref_count);
}

static void ir_print_prefix_gen(IrPrintGen *irp, Stage1AirInst *instruction, bool trailing) {
    ir_print_indent_gen(irp);
    const char mark = trailing ? ':' : '#';
    const char *type_name = instruction->value->type ? buf_ptr(&instruction->value->type->name) : "(unknown)";
    const char *ref_count = ir_inst_gen_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%" PRIu32 "", instruction->ref_count));
    fprintf(irp->f, "%c%-3" PRIu32 "| %-22s| %-12s| %-2s| ", mark, instruction->debug_id,
        ir_inst_gen_type_str(instruction->id), type_name, ref_count);
}

static void ir_print_var_src(IrPrintSrc *irp, Stage1ZirInst *inst) {
    fprintf(irp->f, "#%" PRIu32 "", inst->debug_id);
}

static void ir_print_var_gen(IrPrintGen *irp, Stage1AirInst *inst) {
    fprintf(irp->f, "#%" PRIu32 "", inst->debug_id);
    if (irp->printed.maybe_get(inst) == nullptr) {
        irp->printed.put(inst, 0);
        irp->pending.append(inst);
    }
}

static void ir_print_other_inst_src(IrPrintSrc *irp, Stage1ZirInst *inst) {
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

static void ir_print_other_inst_gen(IrPrintGen *irp, Stage1AirInst *inst) {
    if (inst == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_var_gen(irp, inst);
    }
}

static void ir_print_other_block(IrPrintSrc *irp, Stage1ZirBasicBlock *bb) {
    if (bb == nullptr) {
        fprintf(irp->f, "(null block)");
    } else {
        fprintf(irp->f, "$%s_%" PRIu32 "", bb->name_hint, bb->debug_id);
    }
}

static void ir_print_other_block_gen(IrPrintGen *irp, Stage1AirBasicBlock *bb) {
    if (bb == nullptr) {
        fprintf(irp->f, "(null block)");
    } else {
        fprintf(irp->f, "$%s_%" PRIu32 "", bb->name_hint, bb->debug_id);
    }
}

static void ir_print_return_src(IrPrintSrc *irp, Stage1ZirInstReturn *inst) {
    fprintf(irp->f, "return ");
    ir_print_other_inst_src(irp, inst->operand);
}

static void ir_print_return_gen(IrPrintGen *irp, Stage1AirInstReturn *inst) {
    fprintf(irp->f, "return ");
    ir_print_other_inst_gen(irp, inst->operand);
}

static void ir_print_const(IrPrintSrc *irp, Stage1ZirInstConst *const_instruction) {
    ir_print_const_value(irp->codegen, irp->f, const_instruction->value);
}

static void ir_print_const(IrPrintGen *irp, Stage1AirInstConst *const_instruction) {
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

static void ir_print_un_op(IrPrintSrc *irp, Stage1ZirInstUnOp *inst) {
    fprintf(irp->f, "%s ", ir_un_op_id_str(inst->op_id));
    ir_print_other_inst_src(irp, inst->value);
}

static void ir_print_bin_op(IrPrintSrc *irp, Stage1ZirInstBinOp *bin_op_instruction) {
    ir_print_other_inst_src(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_inst_src(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_bin_op(IrPrintGen *irp, Stage1AirInstBinOp *bin_op_instruction) {
    ir_print_other_inst_gen(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_inst_gen(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_merge_err_sets(IrPrintSrc *irp, Stage1ZirInstMergeErrSets *instruction) {
    ir_print_other_inst_src(irp, instruction->op1);
    fprintf(irp->f, " || ");
    ir_print_other_inst_src(irp, instruction->op2);
    if (instruction->type_name != nullptr) {
        fprintf(irp->f, " // name=%s", buf_ptr(instruction->type_name));
    }
}

static void ir_print_decl_var_src(IrPrintSrc *irp, Stage1ZirInstDeclVar *decl_var_instruction) {
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

static void ir_print_cast(IrPrintGen *irp, Stage1AirInstCast *cast_instruction) {
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

static void ir_print_call_extra(IrPrintSrc *irp, Stage1ZirInstCallExtra *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_inst_src(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=");
    ir_print_other_inst_src(irp, instruction->args);
    fprintf(irp->f, ", result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_async_call_extra(IrPrintSrc *irp, Stage1ZirInstAsyncCallExtra *instruction) {
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

static void ir_print_call_args(IrPrintSrc *irp, Stage1ZirInstCallArgs *instruction) {
    fprintf(irp->f, "opts=");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ", fn=");
    ir_print_other_inst_src(irp, instruction->fn_ref);
    fprintf(irp->f, ", args=(");
    for (size_t i = 0; i < instruction->args_len; i += 1) {
        Stage1ZirInst *arg = instruction->args_ptr[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, arg);
    }
    fprintf(irp->f, "), result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_call_src(IrPrintSrc *irp, Stage1ZirInstCall *call_instruction) {
    ir_print_call_modifier(irp->f, call_instruction->modifier);
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_inst_src(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        Stage1ZirInst *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, call_instruction->result_loc);
}

static void ir_print_call_gen(IrPrintGen *irp, Stage1AirInstCall *call_instruction) {
    ir_print_call_modifier(irp->f, call_instruction->modifier);
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_inst_gen(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        Stage1AirInst *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_inst_gen(irp, arg);
    }
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, call_instruction->result_loc);
}

static void ir_print_cond_br(IrPrintSrc *irp, Stage1ZirInstCondBr *inst) {
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

static void ir_print_cond_br(IrPrintGen *irp, Stage1AirInstCondBr *inst) {
    fprintf(irp->f, "if (");
    ir_print_other_inst_gen(irp, inst->condition);
    fprintf(irp->f, ") ");
    ir_print_other_block_gen(irp, inst->then_block);
    fprintf(irp->f, " else ");
    ir_print_other_block_gen(irp, inst->else_block);
}

static void ir_print_br(IrPrintSrc *irp, Stage1ZirInstBr *br_instruction) {
    fprintf(irp->f, "goto ");
    ir_print_other_block(irp, br_instruction->dest_block);
    if (br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_inst_src(irp, br_instruction->is_comptime);
    }
}

static void ir_print_br(IrPrintGen *irp, Stage1AirInstBr *inst) {
    fprintf(irp->f, "goto ");
    ir_print_other_block_gen(irp, inst->dest_block);
}

static void ir_print_phi(IrPrintSrc *irp, Stage1ZirInstPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        Stage1ZirBasicBlock *incoming_block = phi_instruction->incoming_blocks[i];
        Stage1ZirInst *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_inst_src(irp, incoming_value);
    }
}

static void ir_print_phi(IrPrintGen *irp, Stage1AirInstPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        Stage1AirBasicBlock *incoming_block = phi_instruction->incoming_blocks[i];
        Stage1AirInst *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block_gen(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_inst_gen(irp, incoming_value);
    }
}

static void ir_print_container_init_list(IrPrintSrc *irp, Stage1ZirInstContainerInitList *instruction) {
    fprintf(irp->f, "{");
    if (instruction->item_count > 50) {
        fprintf(irp->f, "...(%" ZIG_PRI_usize " items)...", instruction->item_count);
    } else {
        for (size_t i = 0; i < instruction->item_count; i += 1) {
            Stage1ZirInst *result_loc = instruction->elem_result_loc_list[i];
            if (i != 0)
                fprintf(irp->f, ", ");
            ir_print_other_inst_src(irp, result_loc);
        }
    }
    fprintf(irp->f, "}result=");
    ir_print_other_inst_src(irp, instruction->result_loc);
}

static void ir_print_container_init_fields(IrPrintSrc *irp, Stage1ZirInstContainerInitFields *instruction) {
    fprintf(irp->f, "{");
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        Stage1ZirInstContainerInitFieldsField *field = &instruction->fields[i];
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(field->name));
        ir_print_other_inst_src(irp, field->result_loc);
    }
    fprintf(irp->f, "}result=");
    ir_print_other_inst_src(irp, instruction->result_loc);
}

static void ir_print_unreachable(IrPrintSrc *irp, Stage1ZirInstUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_unreachable(IrPrintGen *irp, Stage1AirInstUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_elem_ptr(IrPrintSrc *irp, Stage1ZirInstElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_src(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_elem_ptr(IrPrintGen *irp, Stage1AirInstElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_gen(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_gen(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_var_ptr(IrPrintSrc *irp, Stage1ZirInstVarPtr *instruction) {
    fprintf(irp->f, "&%s", instruction->var->name);
}

static void ir_print_var_ptr(IrPrintGen *irp, Stage1AirInstVarPtr *instruction) {
    fprintf(irp->f, "&%s", instruction->var->name);
}

static void ir_print_return_ptr(IrPrintGen *irp, Stage1AirInstReturnPtr *instruction) {
    fprintf(irp->f, "@ReturnPtr");
}

static void ir_print_load_ptr(IrPrintSrc *irp, Stage1ZirInstLoadPtr *instruction) {
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ".*");
}

static void ir_print_load_ptr_gen(IrPrintGen *irp, Stage1AirInstLoadPtr *instruction) {
    fprintf(irp->f, "loadptr(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_store_ptr(IrPrintSrc *irp, Stage1ZirInstStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_src(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_store_ptr(IrPrintGen *irp, Stage1AirInstStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_gen(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_vector_store_elem(IrPrintGen *irp, Stage1AirInstVectorStoreElem *instruction) {
    fprintf(irp->f, "vector_ptr=");
    ir_print_var_gen(irp, instruction->vector_ptr);
    fprintf(irp->f, ",index=");
    ir_print_var_gen(irp, instruction->index);
    fprintf(irp->f, ",value=");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_typeof(IrPrintSrc *irp, Stage1ZirInstTypeOf *instruction) {
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

static void ir_print_binary_not(IrPrintGen *irp, Stage1AirInstBinaryNot *instruction) {
    fprintf(irp->f, "~");
    ir_print_other_inst_gen(irp, instruction->operand);
}

static void ir_print_negation(IrPrintGen *irp, Stage1AirInstNegation *instruction) {
    fprintf(irp->f, instruction->wrapping ? "-%%" : "-");
    ir_print_other_inst_gen(irp, instruction->operand);
}

static void ir_print_field_ptr(IrPrintSrc *irp, Stage1ZirInstFieldPtr *instruction) {
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

static void ir_print_struct_field_ptr(IrPrintGen *irp, Stage1AirInstStructFieldPtr *instruction) {
    fprintf(irp->f, "@StructFieldPtr(&");
    ir_print_other_inst_gen(irp, instruction->struct_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_union_field_ptr(IrPrintGen *irp, Stage1AirInstUnionFieldPtr *instruction) {
    fprintf(irp->f, "@UnionFieldPtr(&");
    ir_print_other_inst_gen(irp, instruction->union_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->enum_field->name));
    fprintf(irp->f, ")");
}

static void ir_print_set_cold(IrPrintSrc *irp, Stage1ZirInstSetCold *instruction) {
    fprintf(irp->f, "@setCold(");
    ir_print_other_inst_src(irp, instruction->is_cold);
    fprintf(irp->f, ")");
}

static void ir_print_set_runtime_safety(IrPrintSrc *irp, Stage1ZirInstSetRuntimeSafety *instruction) {
    fprintf(irp->f, "@setRuntimeSafety(");
    ir_print_other_inst_src(irp, instruction->safety_on);
    fprintf(irp->f, ")");
}

static void ir_print_set_float_mode(IrPrintSrc *irp, Stage1ZirInstSetFloatMode *instruction) {
    fprintf(irp->f, "@setFloatMode(");
    ir_print_other_inst_src(irp, instruction->scope_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->mode_value);
    fprintf(irp->f, ")");
}

static void ir_print_array_type(IrPrintSrc *irp, Stage1ZirInstArrayType *instruction) {
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->size);
    if (instruction->sentinel != nullptr) {
        fprintf(irp->f, ":");
        ir_print_other_inst_src(irp, instruction->sentinel);
    }
    fprintf(irp->f, "]");
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_slice_type(IrPrintSrc *irp, Stage1ZirInstSliceType *instruction) {
    const char *const_kw = instruction->is_const ? "const " : "";
    fprintf(irp->f, "[]%s", const_kw);
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_any_frame_type(IrPrintSrc *irp, Stage1ZirInstAnyFrameType *instruction) {
    if (instruction->payload_type == nullptr) {
        fprintf(irp->f, "anyframe");
    } else {
        fprintf(irp->f, "anyframe->");
        ir_print_other_inst_src(irp, instruction->payload_type);
    }
}

static void ir_print_asm_src(IrPrintSrc *irp, Stage1ZirInstAsm *instruction) {
    assert(instruction->base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.source_node->data.asm_expr;
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

static void ir_print_asm_gen(IrPrintGen *irp, Stage1AirInstAsm *instruction) {
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

static void ir_print_size_of(IrPrintSrc *irp, Stage1ZirInstSizeOf *instruction) {
    if (instruction->bit_size)
        fprintf(irp->f, "@bitSizeOf(");
    else
        fprintf(irp->f, "@sizeOf(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_test_non_null(IrPrintSrc *irp, Stage1ZirInstTestNonNull *instruction) {
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_test_non_null(IrPrintGen *irp, Stage1AirInstTestNonNull *instruction) {
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_optional_unwrap_ptr(IrPrintSrc *irp, Stage1ZirInstOptionalUnwrapPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_src(irp, instruction->base_ptr);
    fprintf(irp->f, ".*.?");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_optional_unwrap_ptr(IrPrintGen *irp, Stage1AirInstOptionalUnwrapPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_inst_gen(irp, instruction->base_ptr);
    fprintf(irp->f, ".*.?");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_clz(IrPrintSrc *irp, Stage1ZirInstClz *instruction) {
    fprintf(irp->f, "@clz(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_clz(IrPrintGen *irp, Stage1AirInstClz *instruction) {
    fprintf(irp->f, "@clz(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrintSrc *irp, Stage1ZirInstCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrintGen *irp, Stage1AirInstCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_pop_count(IrPrintSrc *irp, Stage1ZirInstPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_pop_count(IrPrintGen *irp, Stage1AirInstPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bswap(IrPrintSrc *irp, Stage1ZirInstBswap *instruction) {
    fprintf(irp->f, "@byteSwap(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bswap(IrPrintGen *irp, Stage1AirInstBswap *instruction) {
    fprintf(irp->f, "@byteSwap(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bit_reverse(IrPrintSrc *irp, Stage1ZirInstBitReverse *instruction) {
    fprintf(irp->f, "@bitReverse(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_bit_reverse(IrPrintGen *irp, Stage1AirInstBitReverse *instruction) {
    fprintf(irp->f, "@bitReverse(");
    ir_print_other_inst_gen(irp, instruction->op);
    fprintf(irp->f, ")");
}

static void ir_print_switch_br(IrPrintSrc *irp, Stage1ZirInstSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_inst_src(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        Stage1ZirInstSwitchBrCase *this_case = &instruction->cases[i];
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

static void ir_print_switch_br(IrPrintGen *irp, Stage1AirInstSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_inst_gen(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        Stage1AirInstSwitchBrCase *this_case = &instruction->cases[i];
        ir_print_other_inst_gen(irp, this_case->value);
        fprintf(irp->f, " => ");
        ir_print_other_block_gen(irp, this_case->block);
        fprintf(irp->f, ", ");
    }
    fprintf(irp->f, "else => ");
    ir_print_other_block_gen(irp, instruction->else_block);
}

static void ir_print_switch_var(IrPrintSrc *irp, Stage1ZirInstSwitchVar *instruction) {
    fprintf(irp->f, "switchvar ");
    ir_print_other_inst_src(irp, instruction->target_value_ptr);
    for (size_t i = 0; i < instruction->prongs_len; i += 1) {
        fprintf(irp->f, ", ");
        ir_print_other_inst_src(irp, instruction->prongs_ptr[i]);
    }
}

static void ir_print_switch_else_var(IrPrintSrc *irp, Stage1ZirInstSwitchElseVar *instruction) {
    fprintf(irp->f, "switchelsevar ");
    ir_print_other_inst_src(irp, &instruction->switch_br->base);
}

static void ir_print_switch_target(IrPrintSrc *irp, Stage1ZirInstSwitchTarget *instruction) {
    fprintf(irp->f, "switchtarget ");
    ir_print_other_inst_src(irp, instruction->target_value_ptr);
}

static void ir_print_union_tag(IrPrintGen *irp, Stage1AirInstUnionTag *instruction) {
    fprintf(irp->f, "uniontag ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_import(IrPrintSrc *irp, Stage1ZirInstImport *instruction) {
    fprintf(irp->f, "@import(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_ref(IrPrintSrc *irp, Stage1ZirInstRef *instruction) {
    fprintf(irp->f, "ref ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_ref_gen(IrPrintGen *irp, Stage1AirInstRef *instruction) {
    fprintf(irp->f, "@ref(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_compile_err(IrPrintSrc *irp, Stage1ZirInstCompileErr *instruction) {
    fprintf(irp->f, "@compileError(");
    ir_print_other_inst_src(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_compile_log(IrPrintSrc *irp, Stage1ZirInstCompileLog *instruction) {
    fprintf(irp->f, "@compileLog(");
    for (size_t i = 0; i < instruction->msg_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        Stage1ZirInst *msg = instruction->msg_list[i];
        ir_print_other_inst_src(irp, msg);
    }
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrintSrc *irp, Stage1ZirInstErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrintGen *irp, Stage1AirInstErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_import(IrPrintSrc *irp, Stage1ZirInstCImport *instruction) {
    fprintf(irp->f, "@cImport(...)");
}

static void ir_print_c_include(IrPrintSrc *irp, Stage1ZirInstCInclude *instruction) {
    fprintf(irp->f, "@cInclude(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_c_define(IrPrintSrc *irp, Stage1ZirInstCDefine *instruction) {
    fprintf(irp->f, "@cDefine(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_undef(IrPrintSrc *irp, Stage1ZirInstCUndef *instruction) {
    fprintf(irp->f, "@cUndef(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_embed_file(IrPrintSrc *irp, Stage1ZirInstEmbedFile *instruction) {
    fprintf(irp->f, "@embedFile(");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_cmpxchg_src(IrPrintSrc *irp, Stage1ZirInstCmpxchg *instruction) {
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

static void ir_print_cmpxchg_gen(IrPrintGen *irp, Stage1AirInstCmpxchg *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->new_value);
    fprintf(irp->f, ", TODO print atomic orders)result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_fence(IrPrintSrc *irp, Stage1ZirInstFence *instruction) {
    fprintf(irp->f, "@fence(");
    ir_print_other_inst_src(irp, instruction->order);
    fprintf(irp->f, ")");
}

static void ir_print_reduce(IrPrintSrc *irp, Stage1ZirInstReduce *instruction) {
    fprintf(irp->f, "@reduce(");
    ir_print_other_inst_src(irp, instruction->op);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->value);
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

static void ir_print_fence(IrPrintGen *irp, Stage1AirInstFence *instruction) {
    fprintf(irp->f, "fence %s", atomic_order_str(instruction->order));
}

static const char *reduce_op_str(ReduceOp op) {
    switch (op) {
        case ReduceOp_and: return "And";
        case ReduceOp_or: return "Or";
        case ReduceOp_xor: return "Xor";
        case ReduceOp_min: return "Min";
        case ReduceOp_max: return "Max";
        case ReduceOp_add: return "Add";
        case ReduceOp_mul: return "Mul";
    }
    zig_unreachable();
}

static void ir_print_reduce(IrPrintGen *irp, Stage1AirInstReduce *instruction) {
    fprintf(irp->f, "@reduce(.%s, ", reduce_op_str(instruction->op));
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_truncate(IrPrintSrc *irp, Stage1ZirInstTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_truncate(IrPrintGen *irp, Stage1AirInstTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_cast(IrPrintSrc *irp, Stage1ZirInstIntCast *instruction) {
    fprintf(irp->f, "@intCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_cast(IrPrintSrc *irp, Stage1ZirInstFloatCast *instruction) {
    fprintf(irp->f, "@floatCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_err_set_cast(IrPrintSrc *irp, Stage1ZirInstErrSetCast *instruction) {
    fprintf(irp->f, "@errSetCast(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_float(IrPrintSrc *irp, Stage1ZirInstIntToFloat *instruction) {
    fprintf(irp->f, "@intToFloat(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_to_int(IrPrintSrc *irp, Stage1ZirInstFloatToInt *instruction) {
    fprintf(irp->f, "@floatToInt(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_bool_to_int(IrPrintSrc *irp, Stage1ZirInstBoolToInt *instruction) {
    fprintf(irp->f, "@boolToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_vector_type(IrPrintSrc *irp, Stage1ZirInstVectorType *instruction) {
    fprintf(irp->f, "@Vector(");
    ir_print_other_inst_src(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->elem_type);
    fprintf(irp->f, ")");
}

static void ir_print_shuffle_vector(IrPrintSrc *irp, Stage1ZirInstShuffleVector *instruction) {
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

static void ir_print_shuffle_vector(IrPrintGen *irp, Stage1AirInstShuffleVector *instruction) {
    fprintf(irp->f, "@shuffle(");
    ir_print_other_inst_gen(irp, instruction->a);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->b);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->mask);
    fprintf(irp->f, ")");
}

static void ir_print_splat_src(IrPrintSrc *irp, Stage1ZirInstSplat *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_inst_src(irp, instruction->len);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_splat_gen(IrPrintGen *irp, Stage1AirInstSplat *instruction) {
    fprintf(irp->f, "@splat(");
    ir_print_other_inst_gen(irp, instruction->scalar);
    fprintf(irp->f, ")");
}

static void ir_print_bool_not(IrPrintSrc *irp, Stage1ZirInstBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_inst_src(irp, instruction->value);
}

static void ir_print_bool_not(IrPrintGen *irp, Stage1AirInstBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_inst_gen(irp, instruction->value);
}

static void ir_print_wasm_memory_size(IrPrintSrc *irp, Stage1ZirInstWasmMemorySize *instruction) {
    fprintf(irp->f, "@wasmMemorySize(");
    ir_print_other_inst_src(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_size(IrPrintGen *irp, Stage1AirInstWasmMemorySize *instruction) {
    fprintf(irp->f, "@wasmMemorySize(");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_grow(IrPrintSrc *irp, Stage1ZirInstWasmMemoryGrow *instruction) {
    fprintf(irp->f, "@wasmMemoryGrow(");
    ir_print_other_inst_src(irp, instruction->index);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->delta);
    fprintf(irp->f, ")");
}

static void ir_print_wasm_memory_grow(IrPrintGen *irp, Stage1AirInstWasmMemoryGrow *instruction) {
    fprintf(irp->f, "@wasmMemoryGrow(");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->delta);
    fprintf(irp->f, ")");
}

static void ir_print_builtin_src(IrPrintSrc *irp, Stage1ZirInstSrc *instruction) {
    fprintf(irp->f, "@src()");
}

static void ir_print_memset(IrPrintSrc *irp, Stage1ZirInstMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_inst_src(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memset(IrPrintGen *irp, Stage1AirInstMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_inst_gen(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrintSrc *irp, Stage1ZirInstMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_inst_src(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_src(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrintGen *irp, Stage1AirInstMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_inst_gen(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_inst_gen(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_slice_src(IrPrintSrc *irp, Stage1ZirInstSlice *instruction) {
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_src(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_inst_src(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_result_loc(irp, instruction->result_loc);
}

static void ir_print_slice_gen(IrPrintGen *irp, Stage1AirInstSlice *instruction) {
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_inst_gen(irp, instruction->start);
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_inst_gen(irp, instruction->end);
    fprintf(irp->f, "]result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_breakpoint(IrPrintSrc *irp, Stage1ZirInstBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_breakpoint(IrPrintGen *irp, Stage1AirInstBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_frame_address(IrPrintSrc *irp, Stage1ZirInstFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_frame_address(IrPrintGen *irp, Stage1AirInstFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_handle(IrPrintSrc *irp, Stage1ZirInstFrameHandle *instruction) {
    fprintf(irp->f, "@frame()");
}

static void ir_print_handle(IrPrintGen *irp, Stage1AirInstFrameHandle *instruction) {
    fprintf(irp->f, "@frame()");
}

static void ir_print_frame_type(IrPrintSrc *irp, Stage1ZirInstFrameType *instruction) {
    fprintf(irp->f, "@Frame(");
    ir_print_other_inst_src(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_src(IrPrintSrc *irp, Stage1ZirInstFrameSize *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_inst_src(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_frame_size_gen(IrPrintGen *irp, Stage1AirInstFrameSize *instruction) {
    fprintf(irp->f, "@frameSize(");
    ir_print_other_inst_gen(irp, instruction->fn);
    fprintf(irp->f, ")");
}

static void ir_print_return_address(IrPrintSrc *irp, Stage1ZirInstReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_return_address(IrPrintGen *irp, Stage1AirInstReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_align_of(IrPrintSrc *irp, Stage1ZirInstAlignOf *instruction) {
    fprintf(irp->f, "@alignOf(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_overflow_op(IrPrintSrc *irp, Stage1ZirInstOverflowOp *instruction) {
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

static void ir_print_overflow_op(IrPrintGen *irp, Stage1AirInstOverflowOp *instruction) {
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

static void ir_print_test_err_src(IrPrintSrc *irp, Stage1ZirInstTestErr *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_inst_src(irp, instruction->base_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err_gen(IrPrintGen *irp, Stage1AirInstTestErr *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_inst_gen(irp, instruction->err_union);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrintSrc *irp, Stage1ZirInstUnwrapErrCode *instruction) {
    fprintf(irp->f, "UnwrapErrorCode(");
    ir_print_other_inst_src(irp, instruction->err_union_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrintGen *irp, Stage1AirInstUnwrapErrCode *instruction) {
    fprintf(irp->f, "UnwrapErrorCode(");
    ir_print_other_inst_gen(irp, instruction->err_union_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_payload(IrPrintSrc *irp, Stage1ZirInstUnwrapErrPayload *instruction) {
    fprintf(irp->f, "ErrorUnionFieldPayload(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")safety=%d,init=%d",instruction->safety_check_on, instruction->initializing);
}

static void ir_print_unwrap_err_payload(IrPrintGen *irp, Stage1AirInstUnwrapErrPayload *instruction) {
    fprintf(irp->f, "ErrorUnionFieldPayload(");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ")safety=%d,init=%d",instruction->safety_check_on, instruction->initializing);
}

static void ir_print_optional_wrap(IrPrintGen *irp, Stage1AirInstOptionalWrap *instruction) {
    fprintf(irp->f, "@optionalWrap(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_err_wrap_code(IrPrintGen *irp, Stage1AirInstErrWrapCode *instruction) {
    fprintf(irp->f, "@errWrapCode(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_err_wrap_payload(IrPrintGen *irp, Stage1AirInstErrWrapPayload *instruction) {
    fprintf(irp->f, "@errWrapPayload(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_fn_proto(IrPrintSrc *irp, Stage1ZirInstFnProto *instruction) {
    fprintf(irp->f, "fn(");
    for (size_t i = 0; i < instruction->base.source_node->data.fn_proto.params.length; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        if (instruction->is_var_args && i == instruction->base.source_node->data.fn_proto.params.length - 1) {
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

static void ir_print_test_comptime(IrPrintSrc *irp, Stage1ZirInstTestComptime *instruction) {
    fprintf(irp->f, "@testComptime(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_src(IrPrintSrc *irp, Stage1ZirInstPtrCast *instruction) {
    fprintf(irp->f, "@ptrCast(");
    if (instruction->dest_type) {
        ir_print_other_inst_src(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast_gen(IrPrintGen *irp, Stage1AirInstPtrCast *instruction) {
    fprintf(irp->f, "@ptrCast(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_implicit_cast(IrPrintSrc *irp, Stage1ZirInstImplicitCast *instruction) {
    fprintf(irp->f, "@implicitCast(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_cast->base);
}

static void ir_print_bit_cast_src(IrPrintSrc *irp, Stage1ZirInstBitCast *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_result_loc(irp, &instruction->result_loc_bit_cast->base);
}

static void ir_print_bit_cast_gen(IrPrintGen *irp, Stage1AirInstBitCast *instruction) {
    fprintf(irp->f, "@bitCast(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_widen_or_shorten(IrPrintGen *irp, Stage1AirInstWidenOrShorten *instruction) {
    fprintf(irp->f, "WidenOrShorten(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrintSrc *irp, Stage1ZirInstPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrintGen *irp, Stage1AirInstPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrintSrc *irp, Stage1ZirInstIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrintGen *irp, Stage1AirInstIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrintSrc *irp, Stage1ZirInstIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    ir_print_other_inst_src(irp, instruction->dest_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrintGen *irp, Stage1AirInstIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_enum_to_int(IrPrintSrc *irp, Stage1ZirInstEnumToInt *instruction) {
    fprintf(irp->f, "@enumToInt(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_check_runtime_scope(IrPrintSrc *irp, Stage1ZirInstCheckRuntimeScope *instruction) {
    fprintf(irp->f, "@checkRuntimeScope(");
    ir_print_other_inst_src(irp, instruction->scope_is_comptime);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->is_comptime);
    fprintf(irp->f, ")");
}

static void ir_print_array_to_vector(IrPrintGen *irp, Stage1AirInstArrayToVector *instruction) {
    fprintf(irp->f, "ArrayToVector(");
    ir_print_other_inst_gen(irp, instruction->array);
    fprintf(irp->f, ")");
}

static void ir_print_vector_to_array(IrPrintGen *irp, Stage1AirInstVectorToArray *instruction) {
    fprintf(irp->f, "VectorToArray(");
    ir_print_other_inst_gen(irp, instruction->vector);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_ptr_of_array_to_slice(IrPrintGen *irp, Stage1AirInstPtrOfArrayToSlice *instruction) {
    fprintf(irp->f, "PtrOfArrayToSlice(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")result=");
    ir_print_other_inst_gen(irp, instruction->result_loc);
}

static void ir_print_assert_zero(IrPrintGen *irp, Stage1AirInstAssertZero *instruction) {
    fprintf(irp->f, "AssertZero(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_assert_non_null(IrPrintGen *irp, Stage1AirInstAssertNonNull *instruction) {
    fprintf(irp->f, "AssertNonNull(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_alloca_src(IrPrintSrc *irp, Stage1ZirInstAlloca *instruction) {
    fprintf(irp->f, "Alloca(align=");
    ir_print_other_inst_src(irp, instruction->align);
    fprintf(irp->f, ",name=%s)", instruction->name_hint);
}

static void ir_print_alloca_gen(IrPrintGen *irp, Stage1AirInstAlloca *instruction) {
    fprintf(irp->f, "Alloca(align=%" PRIu32 ",name=%s)", instruction->align, instruction->name_hint);
}

static void ir_print_end_expr(IrPrintSrc *irp, Stage1ZirInstEndExpr *instruction) {
    fprintf(irp->f, "EndExpr(result=");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ",value=");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_err(IrPrintSrc *irp, Stage1ZirInstIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_int_to_err(IrPrintGen *irp, Stage1AirInstIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrintSrc *irp, Stage1ZirInstErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrintGen *irp, Stage1AirInstErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_check_switch_prongs(IrPrintSrc *irp, Stage1ZirInstCheckSwitchProngs *instruction,
        bool have_underscore_prong)
{
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
    const char *have_under_str = have_underscore_prong ? "yes" : "no";
    fprintf(irp->f, " _:%s", have_under_str);
}

static void ir_print_check_statement_is_void(IrPrintSrc *irp, Stage1ZirInstCheckStatementIsVoid *instruction) {
    fprintf(irp->f, "@checkStatementIsVoid(");
    ir_print_other_inst_src(irp, instruction->statement_value);
    fprintf(irp->f, ")");
}

static void ir_print_type_name(IrPrintSrc *irp, Stage1ZirInstTypeName *instruction) {
    fprintf(irp->f, "typename ");
    ir_print_other_inst_src(irp, instruction->type_value);
}

static void ir_print_tag_name(IrPrintSrc *irp, Stage1ZirInstTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_inst_src(irp, instruction->target);
}

static void ir_print_tag_name(IrPrintGen *irp, Stage1AirInstTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_inst_gen(irp, instruction->target);
}

static void ir_print_ptr_type(IrPrintSrc *irp, Stage1ZirInstPtrType *instruction) {
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

static void ir_print_ptr_type_simple(IrPrintSrc *irp, Stage1ZirInstPtrTypeSimple *instruction,
        bool is_const)
{
    fprintf(irp->f, "&");
    const char *const_str = is_const ? "const " : "";
    fprintf(irp->f, "*%s", const_str);
    ir_print_other_inst_src(irp, instruction->child_type);
}

static void ir_print_decl_ref(IrPrintSrc *irp, Stage1ZirInstDeclRef *instruction) {
    const char *ptr_str = (instruction->lval != LValNone) ? "ptr " : "";
    fprintf(irp->f, "declref %s%s", ptr_str, buf_ptr(instruction->tld->name));
}

static void ir_print_panic(IrPrintSrc *irp, Stage1ZirInstPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_inst_src(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_panic(IrPrintGen *irp, Stage1AirInstPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_inst_gen(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrintSrc *irp, Stage1ZirInstFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrintGen *irp, Stage1AirInstFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(%s,", buf_ptr(instruction->field->name));
    ir_print_other_inst_gen(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_offset_of(IrPrintSrc *irp, Stage1ZirInstOffsetOf *instruction) {
    fprintf(irp->f, "@offset_of(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_bit_offset_of(IrPrintSrc *irp, Stage1ZirInstBitOffsetOf *instruction) {
    fprintf(irp->f, "@bit_offset_of(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_type_info(IrPrintSrc *irp, Stage1ZirInstTypeInfo *instruction) {
    fprintf(irp->f, "@typeInfo(");
    ir_print_other_inst_src(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_type(IrPrintSrc *irp, Stage1ZirInstType *instruction) {
    fprintf(irp->f, "@Type(");
    ir_print_other_inst_src(irp, instruction->type_info);
    fprintf(irp->f, ")");
}

static void ir_print_has_field(IrPrintSrc *irp, Stage1ZirInstHasField *instruction) {
    fprintf(irp->f, "@hasField(");
    ir_print_other_inst_src(irp, instruction->container_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_set_eval_branch_quota(IrPrintSrc *irp, Stage1ZirInstSetEvalBranchQuota *instruction) {
    fprintf(irp->f, "@setEvalBranchQuota(");
    ir_print_other_inst_src(irp, instruction->new_quota);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrintSrc *irp, Stage1ZirInstAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    ir_print_other_inst_src(irp, instruction->align_bytes);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrintGen *irp, Stage1AirInstAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    ir_print_other_inst_gen(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_resolve_result(IrPrintSrc *irp, Stage1ZirInstResolveResult *instruction) {
    fprintf(irp->f, "ResolveResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_reset_result(IrPrintSrc *irp, Stage1ZirInstResetResult *instruction) {
    fprintf(irp->f, "ResetResult(");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_set_align_stack(IrPrintSrc *irp, Stage1ZirInstSetAlignStack *instruction) {
    fprintf(irp->f, "@setAlignStack(");
    ir_print_other_inst_src(irp, instruction->align_bytes);
    fprintf(irp->f, ")");
}

static void ir_print_arg_type(IrPrintSrc *irp, Stage1ZirInstArgType *instruction, bool allow_var) {
    fprintf(irp->f, "@ArgType(");
    ir_print_other_inst_src(irp, instruction->fn_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->arg_index);
    fprintf(irp->f, ",");
    if (allow_var) {
        fprintf(irp->f, "allow_var=true");
    } else {
        fprintf(irp->f, "allow_var=false");
    }
    fprintf(irp->f, ")");
}

static void ir_print_export(IrPrintSrc *irp, Stage1ZirInstExport *instruction) {
    fprintf(irp->f, "@export(");
    ir_print_other_inst_src(irp, instruction->target);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ")");
}

static void ir_print_extern(IrPrintGen *irp, Stage1AirInstExtern *instruction) {
    fprintf(irp->f, "@extern(...)");
}

static void ir_print_extern(IrPrintSrc *irp, Stage1ZirInstExtern *instruction) {
    fprintf(irp->f, "@extern(");
    ir_print_other_inst_src(irp, instruction->type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->options);
    fprintf(irp->f, ")");
}

static void ir_print_error_return_trace(IrPrintSrc *irp, Stage1ZirInstErrorReturnTrace *instruction) {
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

static void ir_print_error_return_trace(IrPrintGen *irp, Stage1AirInstErrorReturnTrace *instruction) {
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

static void ir_print_error_union(IrPrintSrc *irp, Stage1ZirInstErrorUnion *instruction) {
    ir_print_other_inst_src(irp, instruction->err_set);
    fprintf(irp->f, "!");
    ir_print_other_inst_src(irp, instruction->payload);
}

static void ir_print_atomic_rmw(IrPrintSrc *irp, Stage1ZirInstAtomicRmw *instruction) {
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

static void ir_print_atomic_rmw(IrPrintGen *irp, Stage1AirInstAtomicRmw *instruction) {
    fprintf(irp->f, "@atomicRmw(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",[TODO print op],");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}

static void ir_print_atomic_load(IrPrintSrc *irp, Stage1ZirInstAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    ir_print_other_inst_src(irp, instruction->operand_type);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->ordering);
    fprintf(irp->f, ")");
}

static void ir_print_atomic_load(IrPrintGen *irp, Stage1AirInstAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}

static void ir_print_atomic_store(IrPrintSrc *irp, Stage1ZirInstAtomicStore *instruction) {
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

static void ir_print_atomic_store(IrPrintGen *irp, Stage1AirInstAtomicStore *instruction) {
    fprintf(irp->f, "@atomicStore(");
    ir_print_other_inst_gen(irp, instruction->ptr);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->value);
    fprintf(irp->f, ",%s)", atomic_order_str(instruction->ordering));
}


static void ir_print_save_err_ret_addr(IrPrintSrc *irp, Stage1ZirInstSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_save_err_ret_addr(IrPrintGen *irp, Stage1AirInstSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_add_implicit_return_type(IrPrintSrc *irp, Stage1ZirInstAddImplicitReturnType *instruction) {
    fprintf(irp->f, "@addImplicitReturnType(");
    ir_print_other_inst_src(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_float_op(IrPrintSrc *irp, Stage1ZirInstFloatOp *instruction) {
    fprintf(irp->f, "@%s(", float_op_to_name(instruction->fn_id));
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_float_op(IrPrintGen *irp, Stage1AirInstFloatOp *instruction) {
    fprintf(irp->f, "@%s(", float_op_to_name(instruction->fn_id));
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_mul_add(IrPrintSrc *irp, Stage1ZirInstMulAdd *instruction) {
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

static void ir_print_mul_add(IrPrintGen *irp, Stage1AirInstMulAdd *instruction) {
    fprintf(irp->f, "@mulAdd(");
    ir_print_other_inst_gen(irp, instruction->op1);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->op2);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->op3);
    fprintf(irp->f, ")");
}

static void ir_print_decl_var_gen(IrPrintGen *irp, Stage1AirInstDeclVar *decl_var_instruction) {
    ZigVar *var = decl_var_instruction->var;
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = decl_var_instruction->var->name;
    fprintf(irp->f, "%s %s: %s align(%u) = ", var_or_const, name, buf_ptr(&var->var_type->name),
            var->align_bytes);

    ir_print_other_inst_gen(irp, decl_var_instruction->var_ptr);
}

static void ir_print_has_decl(IrPrintSrc *irp, Stage1ZirInstHasDecl *instruction) {
    fprintf(irp->f, "@hasDecl(");
    ir_print_other_inst_src(irp, instruction->container);
    fprintf(irp->f, ",");
    ir_print_other_inst_src(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_undeclared_ident(IrPrintSrc *irp, Stage1ZirInstUndeclaredIdent *instruction) {
    fprintf(irp->f, "@undeclaredIdent(%s)", buf_ptr(instruction->name));
}

static void ir_print_union_init_named_field(IrPrintSrc *irp, Stage1ZirInstUnionInitNamedField *instruction) {
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

static void ir_print_suspend_begin(IrPrintSrc *irp, Stage1ZirInstSuspendBegin *instruction) {
    fprintf(irp->f, "@suspendBegin()");
}

static void ir_print_suspend_begin(IrPrintGen *irp, Stage1AirInstSuspendBegin *instruction) {
    fprintf(irp->f, "@suspendBegin()");
}

static void ir_print_suspend_finish(IrPrintSrc *irp, Stage1ZirInstSuspendFinish *instruction) {
    fprintf(irp->f, "@suspendFinish()");
}

static void ir_print_suspend_finish(IrPrintGen *irp, Stage1AirInstSuspendFinish *instruction) {
    fprintf(irp->f, "@suspendFinish()");
}

static void ir_print_resume(IrPrintSrc *irp, Stage1ZirInstResume *instruction) {
    fprintf(irp->f, "resume ");
    ir_print_other_inst_src(irp, instruction->frame);
}

static void ir_print_resume(IrPrintGen *irp, Stage1AirInstResume *instruction) {
    fprintf(irp->f, "resume ");
    ir_print_other_inst_gen(irp, instruction->frame);
}

static void ir_print_await_src(IrPrintSrc *irp, Stage1ZirInstAwait *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_inst_src(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_result_loc(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_await_gen(IrPrintGen *irp, Stage1AirInstAwait *instruction) {
    fprintf(irp->f, "@await(");
    ir_print_other_inst_gen(irp, instruction->frame);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->result_loc);
    fprintf(irp->f, ")");
}

static void ir_print_spill_begin(IrPrintSrc *irp, Stage1ZirInstSpillBegin *instruction) {
    fprintf(irp->f, "@spillBegin(");
    ir_print_other_inst_src(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_spill_begin(IrPrintGen *irp, Stage1AirInstSpillBegin *instruction) {
    fprintf(irp->f, "@spillBegin(");
    ir_print_other_inst_gen(irp, instruction->operand);
    fprintf(irp->f, ")");
}

static void ir_print_spill_end(IrPrintSrc *irp, Stage1ZirInstSpillEnd *instruction) {
    fprintf(irp->f, "@spillEnd(");
    ir_print_other_inst_src(irp, &instruction->begin->base);
    fprintf(irp->f, ")");
}

static void ir_print_spill_end(IrPrintGen *irp, Stage1AirInstSpillEnd *instruction) {
    fprintf(irp->f, "@spillEnd(");
    ir_print_other_inst_gen(irp, &instruction->begin->base);
    fprintf(irp->f, ")");
}

static void ir_print_vector_extract_elem(IrPrintGen *irp, Stage1AirInstVectorExtractElem *instruction) {
    fprintf(irp->f, "@vectorExtractElem(");
    ir_print_other_inst_gen(irp, instruction->vector);
    fprintf(irp->f, ",");
    ir_print_other_inst_gen(irp, instruction->index);
    fprintf(irp->f, ")");
}

static void ir_print_inst_src(IrPrintSrc *irp, Stage1ZirInst *instruction, bool trailing) {
    ir_print_prefix_src(irp, instruction, trailing);
    switch (instruction->id) {
        case Stage1ZirInstIdInvalid:
            zig_unreachable();
        case Stage1ZirInstIdReturn:
            ir_print_return_src(irp, (Stage1ZirInstReturn *)instruction);
            break;
        case Stage1ZirInstIdConst:
            ir_print_const(irp, (Stage1ZirInstConst *)instruction);
            break;
        case Stage1ZirInstIdBinOp:
            ir_print_bin_op(irp, (Stage1ZirInstBinOp *)instruction);
            break;
        case Stage1ZirInstIdMergeErrSets:
            ir_print_merge_err_sets(irp, (Stage1ZirInstMergeErrSets *)instruction);
            break;
        case Stage1ZirInstIdDeclVar:
            ir_print_decl_var_src(irp, (Stage1ZirInstDeclVar *)instruction);
            break;
        case Stage1ZirInstIdCallExtra:
            ir_print_call_extra(irp, (Stage1ZirInstCallExtra *)instruction);
            break;
        case Stage1ZirInstIdAsyncCallExtra:
            ir_print_async_call_extra(irp, (Stage1ZirInstAsyncCallExtra *)instruction);
            break;
        case Stage1ZirInstIdCall:
            ir_print_call_src(irp, (Stage1ZirInstCall *)instruction);
            break;
        case Stage1ZirInstIdCallArgs:
            ir_print_call_args(irp, (Stage1ZirInstCallArgs *)instruction);
            break;
        case Stage1ZirInstIdUnOp:
            ir_print_un_op(irp, (Stage1ZirInstUnOp *)instruction);
            break;
        case Stage1ZirInstIdCondBr:
            ir_print_cond_br(irp, (Stage1ZirInstCondBr *)instruction);
            break;
        case Stage1ZirInstIdBr:
            ir_print_br(irp, (Stage1ZirInstBr *)instruction);
            break;
        case Stage1ZirInstIdPhi:
            ir_print_phi(irp, (Stage1ZirInstPhi *)instruction);
            break;
        case Stage1ZirInstIdContainerInitList:
            ir_print_container_init_list(irp, (Stage1ZirInstContainerInitList *)instruction);
            break;
        case Stage1ZirInstIdContainerInitFields:
            ir_print_container_init_fields(irp, (Stage1ZirInstContainerInitFields *)instruction);
            break;
        case Stage1ZirInstIdUnreachable:
            ir_print_unreachable(irp, (Stage1ZirInstUnreachable *)instruction);
            break;
        case Stage1ZirInstIdElemPtr:
            ir_print_elem_ptr(irp, (Stage1ZirInstElemPtr *)instruction);
            break;
        case Stage1ZirInstIdVarPtr:
            ir_print_var_ptr(irp, (Stage1ZirInstVarPtr *)instruction);
            break;
        case Stage1ZirInstIdLoadPtr:
            ir_print_load_ptr(irp, (Stage1ZirInstLoadPtr *)instruction);
            break;
        case Stage1ZirInstIdStorePtr:
            ir_print_store_ptr(irp, (Stage1ZirInstStorePtr *)instruction);
            break;
        case Stage1ZirInstIdTypeOf:
            ir_print_typeof(irp, (Stage1ZirInstTypeOf *)instruction);
            break;
        case Stage1ZirInstIdFieldPtr:
            ir_print_field_ptr(irp, (Stage1ZirInstFieldPtr *)instruction);
            break;
        case Stage1ZirInstIdSetCold:
            ir_print_set_cold(irp, (Stage1ZirInstSetCold *)instruction);
            break;
        case Stage1ZirInstIdSetRuntimeSafety:
            ir_print_set_runtime_safety(irp, (Stage1ZirInstSetRuntimeSafety *)instruction);
            break;
        case Stage1ZirInstIdSetFloatMode:
            ir_print_set_float_mode(irp, (Stage1ZirInstSetFloatMode *)instruction);
            break;
        case Stage1ZirInstIdArrayType:
            ir_print_array_type(irp, (Stage1ZirInstArrayType *)instruction);
            break;
        case Stage1ZirInstIdSliceType:
            ir_print_slice_type(irp, (Stage1ZirInstSliceType *)instruction);
            break;
        case Stage1ZirInstIdAnyFrameType:
            ir_print_any_frame_type(irp, (Stage1ZirInstAnyFrameType *)instruction);
            break;
        case Stage1ZirInstIdAsm:
            ir_print_asm_src(irp, (Stage1ZirInstAsm *)instruction);
            break;
        case Stage1ZirInstIdSizeOf:
            ir_print_size_of(irp, (Stage1ZirInstSizeOf *)instruction);
            break;
        case Stage1ZirInstIdTestNonNull:
            ir_print_test_non_null(irp, (Stage1ZirInstTestNonNull *)instruction);
            break;
        case Stage1ZirInstIdOptionalUnwrapPtr:
            ir_print_optional_unwrap_ptr(irp, (Stage1ZirInstOptionalUnwrapPtr *)instruction);
            break;
        case Stage1ZirInstIdPopCount:
            ir_print_pop_count(irp, (Stage1ZirInstPopCount *)instruction);
            break;
        case Stage1ZirInstIdCtz:
            ir_print_ctz(irp, (Stage1ZirInstCtz *)instruction);
            break;
        case Stage1ZirInstIdBswap:
            ir_print_bswap(irp, (Stage1ZirInstBswap *)instruction);
            break;
        case Stage1ZirInstIdBitReverse:
            ir_print_bit_reverse(irp, (Stage1ZirInstBitReverse *)instruction);
            break;
        case Stage1ZirInstIdSwitchBr:
            ir_print_switch_br(irp, (Stage1ZirInstSwitchBr *)instruction);
            break;
        case Stage1ZirInstIdSwitchVar:
            ir_print_switch_var(irp, (Stage1ZirInstSwitchVar *)instruction);
            break;
        case Stage1ZirInstIdSwitchElseVar:
            ir_print_switch_else_var(irp, (Stage1ZirInstSwitchElseVar *)instruction);
            break;
        case Stage1ZirInstIdSwitchTarget:
            ir_print_switch_target(irp, (Stage1ZirInstSwitchTarget *)instruction);
            break;
        case Stage1ZirInstIdImport:
            ir_print_import(irp, (Stage1ZirInstImport *)instruction);
            break;
        case Stage1ZirInstIdRef:
            ir_print_ref(irp, (Stage1ZirInstRef *)instruction);
            break;
        case Stage1ZirInstIdCompileErr:
            ir_print_compile_err(irp, (Stage1ZirInstCompileErr *)instruction);
            break;
        case Stage1ZirInstIdCompileLog:
            ir_print_compile_log(irp, (Stage1ZirInstCompileLog *)instruction);
            break;
        case Stage1ZirInstIdErrName:
            ir_print_err_name(irp, (Stage1ZirInstErrName *)instruction);
            break;
        case Stage1ZirInstIdCImport:
            ir_print_c_import(irp, (Stage1ZirInstCImport *)instruction);
            break;
        case Stage1ZirInstIdCInclude:
            ir_print_c_include(irp, (Stage1ZirInstCInclude *)instruction);
            break;
        case Stage1ZirInstIdCDefine:
            ir_print_c_define(irp, (Stage1ZirInstCDefine *)instruction);
            break;
        case Stage1ZirInstIdCUndef:
            ir_print_c_undef(irp, (Stage1ZirInstCUndef *)instruction);
            break;
        case Stage1ZirInstIdEmbedFile:
            ir_print_embed_file(irp, (Stage1ZirInstEmbedFile *)instruction);
            break;
        case Stage1ZirInstIdCmpxchg:
            ir_print_cmpxchg_src(irp, (Stage1ZirInstCmpxchg *)instruction);
            break;
        case Stage1ZirInstIdFence:
            ir_print_fence(irp, (Stage1ZirInstFence *)instruction);
            break;
        case Stage1ZirInstIdReduce:
            ir_print_reduce(irp, (Stage1ZirInstReduce *)instruction);
            break;
        case Stage1ZirInstIdTruncate:
            ir_print_truncate(irp, (Stage1ZirInstTruncate *)instruction);
            break;
        case Stage1ZirInstIdIntCast:
            ir_print_int_cast(irp, (Stage1ZirInstIntCast *)instruction);
            break;
        case Stage1ZirInstIdFloatCast:
            ir_print_float_cast(irp, (Stage1ZirInstFloatCast *)instruction);
            break;
        case Stage1ZirInstIdErrSetCast:
            ir_print_err_set_cast(irp, (Stage1ZirInstErrSetCast *)instruction);
            break;
        case Stage1ZirInstIdIntToFloat:
            ir_print_int_to_float(irp, (Stage1ZirInstIntToFloat *)instruction);
            break;
        case Stage1ZirInstIdFloatToInt:
            ir_print_float_to_int(irp, (Stage1ZirInstFloatToInt *)instruction);
            break;
        case Stage1ZirInstIdBoolToInt:
            ir_print_bool_to_int(irp, (Stage1ZirInstBoolToInt *)instruction);
            break;
        case Stage1ZirInstIdVectorType:
            ir_print_vector_type(irp, (Stage1ZirInstVectorType *)instruction);
            break;
        case Stage1ZirInstIdShuffleVector:
            ir_print_shuffle_vector(irp, (Stage1ZirInstShuffleVector *)instruction);
            break;
        case Stage1ZirInstIdSplat:
            ir_print_splat_src(irp, (Stage1ZirInstSplat *)instruction);
            break;
        case Stage1ZirInstIdBoolNot:
            ir_print_bool_not(irp, (Stage1ZirInstBoolNot *)instruction);
            break;
        case Stage1ZirInstIdMemset:
            ir_print_memset(irp, (Stage1ZirInstMemset *)instruction);
            break;
        case Stage1ZirInstIdMemcpy:
            ir_print_memcpy(irp, (Stage1ZirInstMemcpy *)instruction);
            break;
        case Stage1ZirInstIdSlice:
            ir_print_slice_src(irp, (Stage1ZirInstSlice *)instruction);
            break;
        case Stage1ZirInstIdBreakpoint:
            ir_print_breakpoint(irp, (Stage1ZirInstBreakpoint *)instruction);
            break;
        case Stage1ZirInstIdReturnAddress:
            ir_print_return_address(irp, (Stage1ZirInstReturnAddress *)instruction);
            break;
        case Stage1ZirInstIdFrameAddress:
            ir_print_frame_address(irp, (Stage1ZirInstFrameAddress *)instruction);
            break;
        case Stage1ZirInstIdFrameHandle:
            ir_print_handle(irp, (Stage1ZirInstFrameHandle *)instruction);
            break;
        case Stage1ZirInstIdFrameType:
            ir_print_frame_type(irp, (Stage1ZirInstFrameType *)instruction);
            break;
        case Stage1ZirInstIdFrameSize:
            ir_print_frame_size_src(irp, (Stage1ZirInstFrameSize *)instruction);
            break;
        case Stage1ZirInstIdAlignOf:
            ir_print_align_of(irp, (Stage1ZirInstAlignOf *)instruction);
            break;
        case Stage1ZirInstIdOverflowOp:
            ir_print_overflow_op(irp, (Stage1ZirInstOverflowOp *)instruction);
            break;
        case Stage1ZirInstIdTestErr:
            ir_print_test_err_src(irp, (Stage1ZirInstTestErr *)instruction);
            break;
        case Stage1ZirInstIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (Stage1ZirInstUnwrapErrCode *)instruction);
            break;
        case Stage1ZirInstIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (Stage1ZirInstUnwrapErrPayload *)instruction);
            break;
        case Stage1ZirInstIdFnProto:
            ir_print_fn_proto(irp, (Stage1ZirInstFnProto *)instruction);
            break;
        case Stage1ZirInstIdTestComptime:
            ir_print_test_comptime(irp, (Stage1ZirInstTestComptime *)instruction);
            break;
        case Stage1ZirInstIdPtrCast:
            ir_print_ptr_cast_src(irp, (Stage1ZirInstPtrCast *)instruction);
            break;
        case Stage1ZirInstIdBitCast:
            ir_print_bit_cast_src(irp, (Stage1ZirInstBitCast *)instruction);
            break;
        case Stage1ZirInstIdPtrToInt:
            ir_print_ptr_to_int(irp, (Stage1ZirInstPtrToInt *)instruction);
            break;
        case Stage1ZirInstIdIntToPtr:
            ir_print_int_to_ptr(irp, (Stage1ZirInstIntToPtr *)instruction);
            break;
        case Stage1ZirInstIdIntToEnum:
            ir_print_int_to_enum(irp, (Stage1ZirInstIntToEnum *)instruction);
            break;
        case Stage1ZirInstIdIntToErr:
            ir_print_int_to_err(irp, (Stage1ZirInstIntToErr *)instruction);
            break;
        case Stage1ZirInstIdErrToInt:
            ir_print_err_to_int(irp, (Stage1ZirInstErrToInt *)instruction);
            break;
        case Stage1ZirInstIdCheckSwitchProngsUnderNo:
            ir_print_check_switch_prongs(irp, (Stage1ZirInstCheckSwitchProngs *)instruction, false);
            break;
        case Stage1ZirInstIdCheckSwitchProngsUnderYes:
            ir_print_check_switch_prongs(irp, (Stage1ZirInstCheckSwitchProngs *)instruction, true);
            break;
        case Stage1ZirInstIdCheckStatementIsVoid:
            ir_print_check_statement_is_void(irp, (Stage1ZirInstCheckStatementIsVoid *)instruction);
            break;
        case Stage1ZirInstIdTypeName:
            ir_print_type_name(irp, (Stage1ZirInstTypeName *)instruction);
            break;
        case Stage1ZirInstIdTagName:
            ir_print_tag_name(irp, (Stage1ZirInstTagName *)instruction);
            break;
        case Stage1ZirInstIdPtrType:
            ir_print_ptr_type(irp, (Stage1ZirInstPtrType *)instruction);
            break;
        case Stage1ZirInstIdPtrTypeSimple:
            ir_print_ptr_type_simple(irp, (Stage1ZirInstPtrTypeSimple *)instruction, false);
            break;
        case Stage1ZirInstIdPtrTypeSimpleConst:
            ir_print_ptr_type_simple(irp, (Stage1ZirInstPtrTypeSimple *)instruction, true);
            break;
        case Stage1ZirInstIdDeclRef:
            ir_print_decl_ref(irp, (Stage1ZirInstDeclRef *)instruction);
            break;
        case Stage1ZirInstIdPanic:
            ir_print_panic(irp, (Stage1ZirInstPanic *)instruction);
            break;
        case Stage1ZirInstIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (Stage1ZirInstFieldParentPtr *)instruction);
            break;
        case Stage1ZirInstIdOffsetOf:
            ir_print_offset_of(irp, (Stage1ZirInstOffsetOf *)instruction);
            break;
        case Stage1ZirInstIdBitOffsetOf:
            ir_print_bit_offset_of(irp, (Stage1ZirInstBitOffsetOf *)instruction);
            break;
        case Stage1ZirInstIdTypeInfo:
            ir_print_type_info(irp, (Stage1ZirInstTypeInfo *)instruction);
            break;
        case Stage1ZirInstIdType:
            ir_print_type(irp, (Stage1ZirInstType *)instruction);
            break;
        case Stage1ZirInstIdHasField:
            ir_print_has_field(irp, (Stage1ZirInstHasField *)instruction);
            break;
        case Stage1ZirInstIdSetEvalBranchQuota:
            ir_print_set_eval_branch_quota(irp, (Stage1ZirInstSetEvalBranchQuota *)instruction);
            break;
        case Stage1ZirInstIdAlignCast:
            ir_print_align_cast(irp, (Stage1ZirInstAlignCast *)instruction);
            break;
        case Stage1ZirInstIdImplicitCast:
            ir_print_implicit_cast(irp, (Stage1ZirInstImplicitCast *)instruction);
            break;
        case Stage1ZirInstIdResolveResult:
            ir_print_resolve_result(irp, (Stage1ZirInstResolveResult *)instruction);
            break;
        case Stage1ZirInstIdResetResult:
            ir_print_reset_result(irp, (Stage1ZirInstResetResult *)instruction);
            break;
        case Stage1ZirInstIdSetAlignStack:
            ir_print_set_align_stack(irp, (Stage1ZirInstSetAlignStack *)instruction);
            break;
        case Stage1ZirInstIdArgTypeAllowVarFalse:
            ir_print_arg_type(irp, (Stage1ZirInstArgType *)instruction, false);
            break;
        case Stage1ZirInstIdArgTypeAllowVarTrue:
            ir_print_arg_type(irp, (Stage1ZirInstArgType *)instruction, true);
            break;
        case Stage1ZirInstIdExport:
            ir_print_export(irp, (Stage1ZirInstExport *)instruction);
            break;
        case Stage1ZirInstIdExtern:
            ir_print_extern(irp, (Stage1ZirInstExtern*)instruction);
            break;
        case Stage1ZirInstIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (Stage1ZirInstErrorReturnTrace *)instruction);
            break;
        case Stage1ZirInstIdErrorUnion:
            ir_print_error_union(irp, (Stage1ZirInstErrorUnion *)instruction);
            break;
        case Stage1ZirInstIdAtomicRmw:
            ir_print_atomic_rmw(irp, (Stage1ZirInstAtomicRmw *)instruction);
            break;
        case Stage1ZirInstIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (Stage1ZirInstSaveErrRetAddr *)instruction);
            break;
        case Stage1ZirInstIdAddImplicitReturnType:
            ir_print_add_implicit_return_type(irp, (Stage1ZirInstAddImplicitReturnType *)instruction);
            break;
        case Stage1ZirInstIdFloatOp:
            ir_print_float_op(irp, (Stage1ZirInstFloatOp *)instruction);
            break;
        case Stage1ZirInstIdMulAdd:
            ir_print_mul_add(irp, (Stage1ZirInstMulAdd *)instruction);
            break;
        case Stage1ZirInstIdAtomicLoad:
            ir_print_atomic_load(irp, (Stage1ZirInstAtomicLoad *)instruction);
            break;
        case Stage1ZirInstIdAtomicStore:
            ir_print_atomic_store(irp, (Stage1ZirInstAtomicStore *)instruction);
            break;
        case Stage1ZirInstIdEnumToInt:
            ir_print_enum_to_int(irp, (Stage1ZirInstEnumToInt *)instruction);
            break;
        case Stage1ZirInstIdCheckRuntimeScope:
            ir_print_check_runtime_scope(irp, (Stage1ZirInstCheckRuntimeScope *)instruction);
            break;
        case Stage1ZirInstIdHasDecl:
            ir_print_has_decl(irp, (Stage1ZirInstHasDecl *)instruction);
            break;
        case Stage1ZirInstIdUndeclaredIdent:
            ir_print_undeclared_ident(irp, (Stage1ZirInstUndeclaredIdent *)instruction);
            break;
        case Stage1ZirInstIdAlloca:
            ir_print_alloca_src(irp, (Stage1ZirInstAlloca *)instruction);
            break;
        case Stage1ZirInstIdEndExpr:
            ir_print_end_expr(irp, (Stage1ZirInstEndExpr *)instruction);
            break;
        case Stage1ZirInstIdUnionInitNamedField:
            ir_print_union_init_named_field(irp, (Stage1ZirInstUnionInitNamedField *)instruction);
            break;
        case Stage1ZirInstIdSuspendBegin:
            ir_print_suspend_begin(irp, (Stage1ZirInstSuspendBegin *)instruction);
            break;
        case Stage1ZirInstIdSuspendFinish:
            ir_print_suspend_finish(irp, (Stage1ZirInstSuspendFinish *)instruction);
            break;
        case Stage1ZirInstIdResume:
            ir_print_resume(irp, (Stage1ZirInstResume *)instruction);
            break;
        case Stage1ZirInstIdAwait:
            ir_print_await_src(irp, (Stage1ZirInstAwait *)instruction);
            break;
        case Stage1ZirInstIdSpillBegin:
            ir_print_spill_begin(irp, (Stage1ZirInstSpillBegin *)instruction);
            break;
        case Stage1ZirInstIdSpillEnd:
            ir_print_spill_end(irp, (Stage1ZirInstSpillEnd *)instruction);
            break;
        case Stage1ZirInstIdClz:
            ir_print_clz(irp, (Stage1ZirInstClz *)instruction);
            break;
        case Stage1ZirInstIdWasmMemorySize:
            ir_print_wasm_memory_size(irp, (Stage1ZirInstWasmMemorySize *)instruction);
            break;
        case Stage1ZirInstIdWasmMemoryGrow:
            ir_print_wasm_memory_grow(irp, (Stage1ZirInstWasmMemoryGrow *)instruction);
            break;
        case Stage1ZirInstIdSrc:
            ir_print_builtin_src(irp, (Stage1ZirInstSrc *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

static void ir_print_inst_gen(IrPrintGen *irp, Stage1AirInst *instruction, bool trailing) {
    ir_print_prefix_gen(irp, instruction, trailing);
    switch (instruction->id) {
        case Stage1AirInstIdInvalid:
            zig_unreachable();
        case Stage1AirInstIdReturn:
            ir_print_return_gen(irp, (Stage1AirInstReturn *)instruction);
            break;
        case Stage1AirInstIdConst:
            ir_print_const(irp, (Stage1AirInstConst *)instruction);
            break;
        case Stage1AirInstIdBinOp:
            ir_print_bin_op(irp, (Stage1AirInstBinOp *)instruction);
            break;
        case Stage1AirInstIdDeclVar:
            ir_print_decl_var_gen(irp, (Stage1AirInstDeclVar *)instruction);
            break;
        case Stage1AirInstIdCast:
            ir_print_cast(irp, (Stage1AirInstCast *)instruction);
            break;
        case Stage1AirInstIdCall:
            ir_print_call_gen(irp, (Stage1AirInstCall *)instruction);
            break;
        case Stage1AirInstIdCondBr:
            ir_print_cond_br(irp, (Stage1AirInstCondBr *)instruction);
            break;
        case Stage1AirInstIdBr:
            ir_print_br(irp, (Stage1AirInstBr *)instruction);
            break;
        case Stage1AirInstIdPhi:
            ir_print_phi(irp, (Stage1AirInstPhi *)instruction);
            break;
        case Stage1AirInstIdUnreachable:
            ir_print_unreachable(irp, (Stage1AirInstUnreachable *)instruction);
            break;
        case Stage1AirInstIdElemPtr:
            ir_print_elem_ptr(irp, (Stage1AirInstElemPtr *)instruction);
            break;
        case Stage1AirInstIdVarPtr:
            ir_print_var_ptr(irp, (Stage1AirInstVarPtr *)instruction);
            break;
        case Stage1AirInstIdReturnPtr:
            ir_print_return_ptr(irp, (Stage1AirInstReturnPtr *)instruction);
            break;
        case Stage1AirInstIdLoadPtr:
            ir_print_load_ptr_gen(irp, (Stage1AirInstLoadPtr *)instruction);
            break;
        case Stage1AirInstIdStorePtr:
            ir_print_store_ptr(irp, (Stage1AirInstStorePtr *)instruction);
            break;
        case Stage1AirInstIdStructFieldPtr:
            ir_print_struct_field_ptr(irp, (Stage1AirInstStructFieldPtr *)instruction);
            break;
        case Stage1AirInstIdUnionFieldPtr:
            ir_print_union_field_ptr(irp, (Stage1AirInstUnionFieldPtr *)instruction);
            break;
        case Stage1AirInstIdAsm:
            ir_print_asm_gen(irp, (Stage1AirInstAsm *)instruction);
            break;
        case Stage1AirInstIdTestNonNull:
            ir_print_test_non_null(irp, (Stage1AirInstTestNonNull *)instruction);
            break;
        case Stage1AirInstIdOptionalUnwrapPtr:
            ir_print_optional_unwrap_ptr(irp, (Stage1AirInstOptionalUnwrapPtr *)instruction);
            break;
        case Stage1AirInstIdPopCount:
            ir_print_pop_count(irp, (Stage1AirInstPopCount *)instruction);
            break;
        case Stage1AirInstIdClz:
            ir_print_clz(irp, (Stage1AirInstClz *)instruction);
            break;
        case Stage1AirInstIdCtz:
            ir_print_ctz(irp, (Stage1AirInstCtz *)instruction);
            break;
        case Stage1AirInstIdBswap:
            ir_print_bswap(irp, (Stage1AirInstBswap *)instruction);
            break;
        case Stage1AirInstIdBitReverse:
            ir_print_bit_reverse(irp, (Stage1AirInstBitReverse *)instruction);
            break;
        case Stage1AirInstIdSwitchBr:
            ir_print_switch_br(irp, (Stage1AirInstSwitchBr *)instruction);
            break;
        case Stage1AirInstIdUnionTag:
            ir_print_union_tag(irp, (Stage1AirInstUnionTag *)instruction);
            break;
        case Stage1AirInstIdRef:
            ir_print_ref_gen(irp, (Stage1AirInstRef *)instruction);
            break;
        case Stage1AirInstIdErrName:
            ir_print_err_name(irp, (Stage1AirInstErrName *)instruction);
            break;
        case Stage1AirInstIdCmpxchg:
            ir_print_cmpxchg_gen(irp, (Stage1AirInstCmpxchg *)instruction);
            break;
        case Stage1AirInstIdFence:
            ir_print_fence(irp, (Stage1AirInstFence *)instruction);
            break;
        case Stage1AirInstIdReduce:
            ir_print_reduce(irp, (Stage1AirInstReduce *)instruction);
            break;
        case Stage1AirInstIdTruncate:
            ir_print_truncate(irp, (Stage1AirInstTruncate *)instruction);
            break;
        case Stage1AirInstIdShuffleVector:
            ir_print_shuffle_vector(irp, (Stage1AirInstShuffleVector *)instruction);
            break;
        case Stage1AirInstIdSplat:
            ir_print_splat_gen(irp, (Stage1AirInstSplat *)instruction);
            break;
        case Stage1AirInstIdBoolNot:
            ir_print_bool_not(irp, (Stage1AirInstBoolNot *)instruction);
            break;
        case Stage1AirInstIdMemset:
            ir_print_memset(irp, (Stage1AirInstMemset *)instruction);
            break;
        case Stage1AirInstIdMemcpy:
            ir_print_memcpy(irp, (Stage1AirInstMemcpy *)instruction);
            break;
        case Stage1AirInstIdSlice:
            ir_print_slice_gen(irp, (Stage1AirInstSlice *)instruction);
            break;
        case Stage1AirInstIdBreakpoint:
            ir_print_breakpoint(irp, (Stage1AirInstBreakpoint *)instruction);
            break;
        case Stage1AirInstIdReturnAddress:
            ir_print_return_address(irp, (Stage1AirInstReturnAddress *)instruction);
            break;
        case Stage1AirInstIdFrameAddress:
            ir_print_frame_address(irp, (Stage1AirInstFrameAddress *)instruction);
            break;
        case Stage1AirInstIdFrameHandle:
            ir_print_handle(irp, (Stage1AirInstFrameHandle *)instruction);
            break;
        case Stage1AirInstIdFrameSize:
            ir_print_frame_size_gen(irp, (Stage1AirInstFrameSize *)instruction);
            break;
        case Stage1AirInstIdOverflowOp:
            ir_print_overflow_op(irp, (Stage1AirInstOverflowOp *)instruction);
            break;
        case Stage1AirInstIdTestErr:
            ir_print_test_err_gen(irp, (Stage1AirInstTestErr *)instruction);
            break;
        case Stage1AirInstIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (Stage1AirInstUnwrapErrCode *)instruction);
            break;
        case Stage1AirInstIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (Stage1AirInstUnwrapErrPayload *)instruction);
            break;
        case Stage1AirInstIdOptionalWrap:
            ir_print_optional_wrap(irp, (Stage1AirInstOptionalWrap *)instruction);
            break;
        case Stage1AirInstIdErrWrapCode:
            ir_print_err_wrap_code(irp, (Stage1AirInstErrWrapCode *)instruction);
            break;
        case Stage1AirInstIdErrWrapPayload:
            ir_print_err_wrap_payload(irp, (Stage1AirInstErrWrapPayload *)instruction);
            break;
        case Stage1AirInstIdPtrCast:
            ir_print_ptr_cast_gen(irp, (Stage1AirInstPtrCast *)instruction);
            break;
        case Stage1AirInstIdBitCast:
            ir_print_bit_cast_gen(irp, (Stage1AirInstBitCast *)instruction);
            break;
        case Stage1AirInstIdWidenOrShorten:
            ir_print_widen_or_shorten(irp, (Stage1AirInstWidenOrShorten *)instruction);
            break;
        case Stage1AirInstIdPtrToInt:
            ir_print_ptr_to_int(irp, (Stage1AirInstPtrToInt *)instruction);
            break;
        case Stage1AirInstIdIntToPtr:
            ir_print_int_to_ptr(irp, (Stage1AirInstIntToPtr *)instruction);
            break;
        case Stage1AirInstIdIntToEnum:
            ir_print_int_to_enum(irp, (Stage1AirInstIntToEnum *)instruction);
            break;
        case Stage1AirInstIdIntToErr:
            ir_print_int_to_err(irp, (Stage1AirInstIntToErr *)instruction);
            break;
        case Stage1AirInstIdErrToInt:
            ir_print_err_to_int(irp, (Stage1AirInstErrToInt *)instruction);
            break;
        case Stage1AirInstIdTagName:
            ir_print_tag_name(irp, (Stage1AirInstTagName *)instruction);
            break;
        case Stage1AirInstIdPanic:
            ir_print_panic(irp, (Stage1AirInstPanic *)instruction);
            break;
        case Stage1AirInstIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (Stage1AirInstFieldParentPtr *)instruction);
            break;
        case Stage1AirInstIdAlignCast:
            ir_print_align_cast(irp, (Stage1AirInstAlignCast *)instruction);
            break;
        case Stage1AirInstIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (Stage1AirInstErrorReturnTrace *)instruction);
            break;
        case Stage1AirInstIdAtomicRmw:
            ir_print_atomic_rmw(irp, (Stage1AirInstAtomicRmw *)instruction);
            break;
        case Stage1AirInstIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (Stage1AirInstSaveErrRetAddr *)instruction);
            break;
        case Stage1AirInstIdFloatOp:
            ir_print_float_op(irp, (Stage1AirInstFloatOp *)instruction);
            break;
        case Stage1AirInstIdMulAdd:
            ir_print_mul_add(irp, (Stage1AirInstMulAdd *)instruction);
            break;
        case Stage1AirInstIdAtomicLoad:
            ir_print_atomic_load(irp, (Stage1AirInstAtomicLoad *)instruction);
            break;
        case Stage1AirInstIdAtomicStore:
            ir_print_atomic_store(irp, (Stage1AirInstAtomicStore *)instruction);
            break;
        case Stage1AirInstIdArrayToVector:
            ir_print_array_to_vector(irp, (Stage1AirInstArrayToVector *)instruction);
            break;
        case Stage1AirInstIdVectorToArray:
            ir_print_vector_to_array(irp, (Stage1AirInstVectorToArray *)instruction);
            break;
        case Stage1AirInstIdPtrOfArrayToSlice:
            ir_print_ptr_of_array_to_slice(irp, (Stage1AirInstPtrOfArrayToSlice *)instruction);
            break;
        case Stage1AirInstIdAssertZero:
            ir_print_assert_zero(irp, (Stage1AirInstAssertZero *)instruction);
            break;
        case Stage1AirInstIdAssertNonNull:
            ir_print_assert_non_null(irp, (Stage1AirInstAssertNonNull *)instruction);
            break;
        case Stage1AirInstIdAlloca:
            ir_print_alloca_gen(irp, (Stage1AirInstAlloca *)instruction);
            break;
        case Stage1AirInstIdSuspendBegin:
            ir_print_suspend_begin(irp, (Stage1AirInstSuspendBegin *)instruction);
            break;
        case Stage1AirInstIdSuspendFinish:
            ir_print_suspend_finish(irp, (Stage1AirInstSuspendFinish *)instruction);
            break;
        case Stage1AirInstIdResume:
            ir_print_resume(irp, (Stage1AirInstResume *)instruction);
            break;
        case Stage1AirInstIdAwait:
            ir_print_await_gen(irp, (Stage1AirInstAwait *)instruction);
            break;
        case Stage1AirInstIdSpillBegin:
            ir_print_spill_begin(irp, (Stage1AirInstSpillBegin *)instruction);
            break;
        case Stage1AirInstIdSpillEnd:
            ir_print_spill_end(irp, (Stage1AirInstSpillEnd *)instruction);
            break;
        case Stage1AirInstIdVectorExtractElem:
            ir_print_vector_extract_elem(irp, (Stage1AirInstVectorExtractElem *)instruction);
            break;
        case Stage1AirInstIdVectorStoreElem:
            ir_print_vector_store_elem(irp, (Stage1AirInstVectorStoreElem *)instruction);
            break;
        case Stage1AirInstIdBinaryNot:
            ir_print_binary_not(irp, (Stage1AirInstBinaryNot *)instruction);
            break;
        case Stage1AirInstIdNegation:
            ir_print_negation(irp, (Stage1AirInstNegation *)instruction);
            break;
        case Stage1AirInstIdWasmMemorySize:
            ir_print_wasm_memory_size(irp, (Stage1AirInstWasmMemorySize *)instruction);
            break;
        case Stage1AirInstIdWasmMemoryGrow:
            ir_print_wasm_memory_grow(irp, (Stage1AirInstWasmMemoryGrow *)instruction);
            break;
        case Stage1AirInstIdExtern:
            ir_print_extern(irp, (Stage1AirInstExtern *)instruction);
            break;

    }
    fprintf(irp->f, "\n");
}

static void irp_print_basic_block_src(IrPrintSrc *irp, Stage1ZirBasicBlock *current_block) {
    fprintf(irp->f, "%s_%" PRIu32 ":\n", current_block->name_hint, current_block->debug_id);
    for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
        Stage1ZirInst *instruction = current_block->instruction_list.at(instr_i);
        ir_print_inst_src(irp, instruction, false);
    }
}

static void irp_print_basic_block_gen(IrPrintGen *irp, Stage1AirBasicBlock *current_block) {
    fprintf(irp->f, "%s_%" PRIu32 ":\n", current_block->name_hint, current_block->debug_id);
    for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
        Stage1AirInst *instruction = current_block->instruction_list.at(instr_i);
        irp->printed.put(instruction, 0);
        irp->pending.clear();
        ir_print_inst_gen(irp, instruction, false);
        for (size_t j = 0; j < irp->pending.length; ++j)
            ir_print_inst_gen(irp, irp->pending.at(j), true);
    }
}

void ir_print_basic_block_src(CodeGen *codegen, FILE *f, Stage1ZirBasicBlock *bb, int indent_size) {
    IrPrintSrc ir_print = {};
    ir_print.codegen = codegen;
    ir_print.f = f;
    ir_print.indent = indent_size;
    ir_print.indent_size = indent_size;

    irp_print_basic_block_src(&ir_print, bb);
}

void ir_print_basic_block_gen(CodeGen *codegen, FILE *f, Stage1AirBasicBlock *bb, int indent_size) {
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

void ir_print_src(CodeGen *codegen, FILE *f, Stage1Zir *executable, int indent_size) {
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

void ir_print_gen(CodeGen *codegen, FILE *f, Stage1Air *executable, int indent_size) {
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

void ir_print_inst_src(CodeGen *codegen, FILE *f, Stage1ZirInst *instruction, int indent_size) {
    IrPrintSrc ir_print = {};
    IrPrintSrc *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    ir_print_inst_src(irp, instruction, false);
}

void ir_print_inst_gen(CodeGen *codegen, FILE *f, Stage1AirInst *instruction, int indent_size) {
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

void Stage1ZirInst::dump() {
    Stage1ZirInst *inst = this;
    inst->src();
    if (inst->scope == nullptr) {
        fprintf(stderr, "(null scope)\n");
    } else {
        ir_print_inst_src(inst->scope->codegen, stderr, inst, 0);
        fprintf(stderr, "-> ");
        ir_print_inst_gen(inst->scope->codegen, stderr, inst->child, 0);
    }
}
