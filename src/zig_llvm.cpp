/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

// This must go before all includes.
#include "config.h"
#if defined(ZIG_LLVM_OLD_CXX_ABI)
#define _GLIBCXX_USE_CXX11_ABI 0
#endif


#include "zig_llvm.hpp"


/*
 * The point of this file is to contain all the LLVM C++ API interaction so that:
 * 1. The compile time of other files is kept under control.
 * 2. Provide a C interface to the LLVM functions we need for self-hosting purposes.
 * 3. Prevent C++ from infecting the rest of the project.
 */

#include <llvm/InitializePasses.h>
#include <llvm/PassRegistry.h>
#include <llvm/MC/SubtargetFeature.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/TargetParser.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Verifier.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/DIBuilder.h>
#include <llvm/IR/DiagnosticInfo.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/Analysis/TargetTransformInfo.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/IPO/PassManagerBuilder.h>
#include <llvm/Transforms/Scalar.h>

using namespace llvm;

void LLVMZigInitializeLoopStrengthReducePass(LLVMPassRegistryRef R) {
    initializeLoopStrengthReducePass(*unwrap(R));
}

void LLVMZigInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R) {
    initializeLowerIntrinsicsPass(*unwrap(R));
}

void LLVMZigInitializeUnreachableBlockElimPass(LLVMPassRegistryRef R) {
    initializeUnreachableBlockElimPass(*unwrap(R));
}

char *LLVMZigGetHostCPUName(void) {
    std::string str = sys::getHostCPUName();
    return strdup(str.c_str());
}

char *LLVMZigGetNativeFeatures(void) {
    SubtargetFeatures features;

    StringMap<bool> host_features;
    if (sys::getHostCPUFeatures(host_features)) {
        for (auto &F : host_features)
            features.AddFeature(F.first(), F.second);
    }

    return strdup(features.getString().c_str());
}

static void addAddDiscriminatorsPass(const PassManagerBuilder &Builder, legacy::PassManagerBase &PM) {
  PM.add(createAddDiscriminatorsPass());
}


void LLVMZigOptimizeModule(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref) {
    TargetMachine* target_machine = reinterpret_cast<TargetMachine*>(targ_machine_ref);
    Module* module = unwrap(module_ref);
    TargetLibraryInfoImpl tlii(Triple(module->getTargetTriple()));

    PassManagerBuilder *PMBuilder = new PassManagerBuilder();
    PMBuilder->OptLevel = target_machine->getOptLevel();
    PMBuilder->SizeLevel = 0;
    PMBuilder->BBVectorize = true;
    PMBuilder->SLPVectorize = true;
    PMBuilder->LoopVectorize = true;

    PMBuilder->DisableUnitAtATime = false;
    PMBuilder->DisableUnrollLoops = false;
    PMBuilder->MergeFunctions = true;
    PMBuilder->PrepareForLTO = true;
    PMBuilder->RerollLoops = true;

    PMBuilder->addExtension(PassManagerBuilder::EP_EarlyAsPossible, addAddDiscriminatorsPass);

    PMBuilder->LibraryInfo = &tlii;

    PMBuilder->Inliner = createFunctionInliningPass(PMBuilder->OptLevel, PMBuilder->SizeLevel);

    // Set up the per-function pass manager.
    legacy::FunctionPassManager *FPM = new legacy::FunctionPassManager(module);
    FPM->add(createTargetTransformInfoWrapperPass(target_machine->getTargetIRAnalysis()));
#ifndef NDEBUG
    bool verify_module = true;
#else
    bool verify_module = false;
#endif
    if (verify_module) {
        FPM->add(createVerifierPass());
    }
    PMBuilder->populateFunctionPassManager(*FPM);

    // Set up the per-module pass manager.
    legacy::PassManager *MPM = new legacy::PassManager();
    MPM->add(createTargetTransformInfoWrapperPass(target_machine->getTargetIRAnalysis()));

    PMBuilder->populateModulePassManager(*MPM);


    // run per function optimization passes
    FPM->doInitialization();
    for (Function &F : *module)
      if (!F.isDeclaration())
        FPM->run(F);
    FPM->doFinalization();

    // run per module optimization passes
    MPM->run(*module);
}

LLVMValueRef LLVMZigBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, const char *Name)
{
    CallInst *call_inst = CallInst::Create(unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), Name);
    call_inst->setCallingConv(CC);
    return wrap(unwrap(B)->Insert(call_inst));
}

void LLVMZigAddNonNullAttr(LLVMValueRef fn, unsigned i)
{
    assert( isa<Function>(unwrap(fn)) );

    Function *unwrapped_function = reinterpret_cast<Function*>(unwrap(fn));

    unwrapped_function->addAttribute(i, Attribute::NonNull);
}


LLVMZigDIType *LLVMZigCreateDebugPointerType(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *pointee_type,
        uint64_t size_in_bits, uint64_t align_in_bits, const char *name)
{
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createPointerType(
            reinterpret_cast<DIType*>(pointee_type), size_in_bits, align_in_bits, name);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugBasicType(LLVMZigDIBuilder *dibuilder, const char *name,
        uint64_t size_in_bits, uint64_t align_in_bits, unsigned encoding)
{
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createBasicType(
            name, size_in_bits, align_in_bits, encoding);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugArrayType(LLVMZigDIBuilder *dibuilder, uint64_t size_in_bits,
        uint64_t align_in_bits, LLVMZigDIType *elem_type, int elem_count)
{
    SmallVector<Metadata *, 1> subrange;
    subrange.push_back(reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateSubrange(0, elem_count));
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createArrayType(
            size_in_bits, align_in_bits,
            reinterpret_cast<DIType*>(elem_type),
            reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateArray(subrange));
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIEnumerator *LLVMZigCreateDebugEnumerator(LLVMZigDIBuilder *dibuilder, const char *name, int64_t val) {
    DIEnumerator *di_enumerator = reinterpret_cast<DIBuilder*>(dibuilder)->createEnumerator(name, val);
    return reinterpret_cast<LLVMZigDIEnumerator*>(di_enumerator);
}

LLVMZigDIType *LLVMZigCreateDebugEnumerationType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, LLVMZigDIEnumerator **enumerator_array, int enumerator_array_len,
        LLVMZigDIType *underlying_type, const char *unique_id)
{
    SmallVector<Metadata *, 8> fields;
    for (int i = 0; i < enumerator_array_len; i += 1) {
        DIEnumerator *dienumerator = reinterpret_cast<DIEnumerator*>(enumerator_array[i]);
        fields.push_back(dienumerator);
    }
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createEnumerationType(
            reinterpret_cast<DIScope*>(scope),
            name,
            reinterpret_cast<DIFile*>(file),
            line_number, size_in_bits, align_in_bits,
            reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateArray(fields),
            reinterpret_cast<DIType*>(underlying_type),
            unique_id);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugMemberType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line, uint64_t size_in_bits,
        uint64_t align_in_bits, uint64_t offset_in_bits, unsigned flags, LLVMZigDIType *type)
{
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createMemberType(
            reinterpret_cast<DIScope*>(scope),
            name,
            reinterpret_cast<DIFile*>(file),
            line, size_in_bits, align_in_bits, offset_in_bits, flags,
            reinterpret_cast<DIType*>(type));
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugUnionType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, LLVMZigDIType **types_array, int types_array_len,
        unsigned run_time_lang, const char *unique_id)
{
    SmallVector<Metadata *, 8> fields;
    for (int i = 0; i < types_array_len; i += 1) {
        DIType *ditype = reinterpret_cast<DIType*>(types_array[i]);
        fields.push_back(ditype);
    }
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createUnionType(
            reinterpret_cast<DIScope*>(scope),
            name,
            reinterpret_cast<DIFile*>(file),
            line_number, size_in_bits, align_in_bits, flags,
            reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateArray(fields),
            run_time_lang, unique_id);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugStructType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, LLVMZigDIType *derived_from, 
        LLVMZigDIType **types_array, int types_array_len, unsigned run_time_lang, LLVMZigDIType *vtable_holder,
        const char *unique_id)
{
    SmallVector<Metadata *, 8> fields;
    for (int i = 0; i < types_array_len; i += 1) {
        DIType *ditype = reinterpret_cast<DIType*>(types_array[i]);
        fields.push_back(ditype);
    }
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createStructType(
            reinterpret_cast<DIScope*>(scope),
            name,
            reinterpret_cast<DIFile*>(file),
            line_number, size_in_bits, align_in_bits, flags,
            reinterpret_cast<DIType*>(derived_from),
            reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateArray(fields),
            run_time_lang,
            reinterpret_cast<DIType*>(vtable_holder),
            unique_id);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateReplaceableCompositeType(LLVMZigDIBuilder *dibuilder, unsigned tag,
        const char *name, LLVMZigDIScope *scope, LLVMZigDIFile *file, unsigned line)
{
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createReplaceableCompositeType(
            tag, name,
            reinterpret_cast<DIScope*>(scope),
            reinterpret_cast<DIFile*>(file),
            line);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

LLVMZigDIType *LLVMZigCreateDebugForwardDeclType(LLVMZigDIBuilder *dibuilder, unsigned tag,
        const char *name, LLVMZigDIScope *scope, LLVMZigDIFile *file, unsigned line)
{
    DIType *di_type = reinterpret_cast<DIBuilder*>(dibuilder)->createForwardDecl(
            tag, name,
            reinterpret_cast<DIScope*>(scope),
            reinterpret_cast<DIFile*>(file),
            line);
    return reinterpret_cast<LLVMZigDIType*>(di_type);
}

void LLVMZigReplaceTemporary(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *type,
        LLVMZigDIType *replacement)
{
    reinterpret_cast<DIBuilder*>(dibuilder)->replaceTemporary(
            TempDIType(reinterpret_cast<DIType*>(type)),
            reinterpret_cast<DIType*>(replacement));
}

void LLVMZigReplaceDebugArrays(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *type,
        LLVMZigDIType **types_array, int types_array_len)
{
    SmallVector<Metadata *, 8> fields;
    for (int i = 0; i < types_array_len; i += 1) {
        DIType *ditype = reinterpret_cast<DIType*>(types_array[i]);
        fields.push_back(ditype);
    }
    DICompositeType *composite_type = (DICompositeType*)reinterpret_cast<DIType*>(type);
    reinterpret_cast<DIBuilder*>(dibuilder)->replaceArrays(
            composite_type,
            reinterpret_cast<DIBuilder*>(dibuilder)->getOrCreateArray(fields));
}

LLVMZigDIType *LLVMZigCreateSubroutineType(LLVMZigDIBuilder *dibuilder_wrapped,
        LLVMZigDIFile *file, LLVMZigDIType **types_array, int types_array_len, unsigned flags)
{
    SmallVector<Metadata *, 8> types;
    for (int i = 0; i < types_array_len; i += 1) {
        DIType *ditype = reinterpret_cast<DIType*>(types_array[i]);
        types.push_back(ditype);
    }
    DIBuilder *dibuilder = reinterpret_cast<DIBuilder*>(dibuilder_wrapped);
    DISubroutineType *subroutine_type = dibuilder->createSubroutineType(
            reinterpret_cast<DIFile*>(file),
            dibuilder->getOrCreateTypeArray(types),
            flags);
    DIType *ditype = subroutine_type;
    return reinterpret_cast<LLVMZigDIType*>(ditype);
}

unsigned LLVMZigEncoding_DW_ATE_unsigned(void) {
    return dwarf::DW_ATE_unsigned;
}

unsigned LLVMZigEncoding_DW_ATE_signed(void) {
    return dwarf::DW_ATE_signed;
}

unsigned LLVMZigEncoding_DW_ATE_float(void) {
    return dwarf::DW_ATE_float;
}

unsigned LLVMZigEncoding_DW_ATE_boolean(void) {
    return dwarf::DW_ATE_boolean;
}

unsigned LLVMZigEncoding_DW_ATE_unsigned_char(void) {
    return dwarf::DW_ATE_unsigned_char;
}

unsigned LLVMZigEncoding_DW_ATE_signed_char(void) {
    return dwarf::DW_ATE_signed_char;
}

unsigned LLVMZigLang_DW_LANG_C99(void) {
    return dwarf::DW_LANG_C99;
}

unsigned LLVMZigTag_DW_auto_variable(void) {
    return dwarf::DW_TAG_auto_variable;
}

unsigned LLVMZigTag_DW_arg_variable(void) {
    return dwarf::DW_TAG_arg_variable;
}

unsigned LLVMZigTag_DW_structure_type(void) {
    return dwarf::DW_TAG_structure_type;
}

LLVMZigDIBuilder *LLVMZigCreateDIBuilder(LLVMModuleRef module, bool allow_unresolved) {
    DIBuilder *di_builder = new DIBuilder(*unwrap(module), allow_unresolved);
    return reinterpret_cast<LLVMZigDIBuilder *>(di_builder);
}

void LLVMZigSetCurrentDebugLocation(LLVMBuilderRef builder, int line, int column, LLVMZigDIScope *scope) {
    unwrap(builder)->SetCurrentDebugLocation(DebugLoc::get(
                line, column, reinterpret_cast<DIScope*>(scope)));
}


LLVMZigDILexicalBlock *LLVMZigCreateLexicalBlock(LLVMZigDIBuilder *dbuilder, LLVMZigDIScope *scope,
        LLVMZigDIFile *file, unsigned line, unsigned col)
{
    DILexicalBlock *result = reinterpret_cast<DIBuilder*>(dbuilder)->createLexicalBlock(
            reinterpret_cast<DIScope*>(scope),
            reinterpret_cast<DIFile*>(file),
            line,
            col);
    return reinterpret_cast<LLVMZigDILexicalBlock*>(result);
}


LLVMZigDILocalVariable *LLVMZigCreateLocalVariable(LLVMZigDIBuilder *dbuilder, unsigned tag,
        LLVMZigDIScope *scope, const char *name, LLVMZigDIFile *file, unsigned line_no,
        LLVMZigDIType *type, bool always_preserve, unsigned flags, unsigned arg_no)
{
    DILocalVariable *result = reinterpret_cast<DIBuilder*>(dbuilder)->createLocalVariable(
            tag,
            reinterpret_cast<DIScope*>(scope),
            name,
            reinterpret_cast<DIFile*>(file),
            line_no,
            reinterpret_cast<DIType*>(type),
            always_preserve,
            flags,
            arg_no);
    return reinterpret_cast<LLVMZigDILocalVariable*>(result);
}

LLVMZigDIScope *LLVMZigLexicalBlockToScope(LLVMZigDILexicalBlock *lexical_block) {
    DIScope *scope = reinterpret_cast<DILexicalBlock*>(lexical_block);
    return reinterpret_cast<LLVMZigDIScope*>(scope);
}

LLVMZigDIScope *LLVMZigCompileUnitToScope(LLVMZigDICompileUnit *compile_unit) {
    DIScope *scope = reinterpret_cast<DICompileUnit*>(compile_unit);
    return reinterpret_cast<LLVMZigDIScope*>(scope);
}

LLVMZigDIScope *LLVMZigFileToScope(LLVMZigDIFile *difile) {
    DIScope *scope = reinterpret_cast<DIFile*>(difile);
    return reinterpret_cast<LLVMZigDIScope*>(scope);
}

LLVMZigDIScope *LLVMZigSubprogramToScope(LLVMZigDISubprogram *subprogram) {
    DIScope *scope = reinterpret_cast<DISubprogram*>(subprogram);
    return reinterpret_cast<LLVMZigDIScope*>(scope);
}

LLVMZigDIScope *LLVMZigTypeToScope(LLVMZigDIType *type) {
    DIScope *scope = reinterpret_cast<DIType*>(type);
    return reinterpret_cast<LLVMZigDIScope*>(scope);
}

LLVMZigDICompileUnit *LLVMZigCreateCompileUnit(LLVMZigDIBuilder *dibuilder,
        unsigned lang, const char *file, const char *dir, const char *producer,
        bool is_optimized, const char *flags, unsigned runtime_version, const char *split_name,
        uint64_t dwo_id, bool emit_debug_info)
{
    DICompileUnit *result = reinterpret_cast<DIBuilder*>(dibuilder)->createCompileUnit(
            lang, file, dir, producer, is_optimized, flags, runtime_version, split_name,
            DIBuilder::FullDebug, dwo_id, emit_debug_info);
    return reinterpret_cast<LLVMZigDICompileUnit*>(result);
}

LLVMZigDIFile *LLVMZigCreateFile(LLVMZigDIBuilder *dibuilder, const char *filename, const char *directory) {
    DIFile *result = reinterpret_cast<DIBuilder*>(dibuilder)->createFile(filename, directory);
    return reinterpret_cast<LLVMZigDIFile*>(result);
}

LLVMZigDISubprogram *LLVMZigCreateFunction(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, const char *linkage_name, LLVMZigDIFile *file, unsigned lineno,
        LLVMZigDIType *fn_di_type, bool is_local_to_unit, bool is_definition, unsigned scope_line,
        unsigned flags, bool is_optimized, LLVMValueRef function)
{
    Function *unwrapped_function = reinterpret_cast<Function*>(unwrap(function));
    DISubroutineType *di_sub_type = static_cast<DISubroutineType*>(reinterpret_cast<DIType*>(fn_di_type));
    DISubprogram *result = reinterpret_cast<DIBuilder*>(dibuilder)->createFunction(
            reinterpret_cast<DIScope*>(scope),
            name, linkage_name,
            reinterpret_cast<DIFile*>(file),
            lineno,
            di_sub_type,
            is_local_to_unit, is_definition, scope_line, flags, is_optimized, unwrapped_function);
    return reinterpret_cast<LLVMZigDISubprogram*>(result);
}

void LLVMZigDIBuilderFinalize(LLVMZigDIBuilder *dibuilder) {
    reinterpret_cast<DIBuilder*>(dibuilder)->finalize();
}

LLVMZigInsertionPoint *LLVMZigSaveInsertPoint(LLVMBuilderRef builder_wrapped) {
    IRBuilderBase::InsertPoint *ip = new IRBuilderBase::InsertPoint();
    *ip = unwrap(builder_wrapped)->saveIP();
    return reinterpret_cast<LLVMZigInsertionPoint*>(ip);
}

void LLVMZigRestoreInsertPoint(LLVMBuilderRef builder, LLVMZigInsertionPoint *ip_wrapped) {
    IRBuilderBase::InsertPoint *ip = reinterpret_cast<IRBuilderBase::InsertPoint*>(ip_wrapped);
    unwrap(builder)->restoreIP(*ip);
}

LLVMValueRef LLVMZigInsertDeclareAtEnd(LLVMZigDIBuilder *dibuilder, LLVMValueRef storage,
        LLVMZigDILocalVariable *var_info, LLVMZigDILocation *debug_loc, LLVMBasicBlockRef basic_block_ref)
{
    Instruction *result = reinterpret_cast<DIBuilder*>(dibuilder)->insertDeclare(
            unwrap(storage),
            reinterpret_cast<DILocalVariable *>(var_info),
            reinterpret_cast<DIBuilder*>(dibuilder)->createExpression(),
            reinterpret_cast<DILocation*>(debug_loc),
            static_cast<BasicBlock*>(unwrap(basic_block_ref)));
    return wrap(result);
}

LLVMValueRef LLVMZigInsertDeclare(LLVMZigDIBuilder *dibuilder, LLVMValueRef storage,
        LLVMZigDILocalVariable *var_info, LLVMZigDILocation *debug_loc, LLVMValueRef insert_before_instr)
{
    Instruction *result = reinterpret_cast<DIBuilder*>(dibuilder)->insertDeclare(
            unwrap(storage),
            reinterpret_cast<DILocalVariable *>(var_info),
            reinterpret_cast<DIBuilder*>(dibuilder)->createExpression(),
            reinterpret_cast<DILocation*>(debug_loc),
            static_cast<Instruction*>(unwrap(insert_before_instr)));
    return wrap(result);
}

LLVMZigDILocation *LLVMZigGetDebugLoc(unsigned line, unsigned col, LLVMZigDIScope *scope) {
    DebugLoc debug_loc = DebugLoc::get(line, col, reinterpret_cast<DIScope*>(scope), nullptr);
    return reinterpret_cast<LLVMZigDILocation*>(debug_loc.get());
}

void LLVMZigSetFastMath(LLVMBuilderRef builder_wrapped, bool on_state) {
    if (on_state) {
        FastMathFlags fmf;
        fmf.setUnsafeAlgebra();
        unwrap(builder_wrapped)->SetFastMathFlags(fmf);
    } else {
        unwrap(builder_wrapped)->clearFastMathFlags();
    }
}


static_assert((Triple::ArchType)ZigLLVM_LastArchType == Triple::LastArchType, "");
static_assert((Triple::VendorType)ZigLLVM_LastVendorType == Triple::LastVendorType, "");
static_assert((Triple::OSType)ZigLLVM_LastOSType == Triple::LastOSType, "");
static_assert((Triple::EnvironmentType)ZigLLVM_LastEnvironmentType == Triple::LastEnvironmentType, "");

static_assert((Triple::ObjectFormatType)ZigLLVM_UnknownObjectFormat == Triple::UnknownObjectFormat, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_COFF == Triple::COFF, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_ELF == Triple::ELF, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_MachO == Triple::MachO, "");

const char *ZigLLVMGetArchTypeName(ZigLLVM_ArchType arch) {
    return Triple::getArchTypeName((Triple::ArchType)arch);
}

const char *ZigLLVMGetVendorTypeName(ZigLLVM_VendorType vendor) {
    return Triple::getVendorTypeName((Triple::VendorType)vendor);
}

const char *ZigLLVMGetOSTypeName(ZigLLVM_OSType os) {
    return Triple::getOSTypeName((Triple::OSType)os);
}

const char *ZigLLVMGetEnvironmentTypeName(ZigLLVM_EnvironmentType env_type) {
    return Triple::getEnvironmentTypeName((Triple::EnvironmentType)env_type);
}

void ZigLLVMGetNativeTarget(ZigLLVM_ArchType *arch_type, ZigLLVM_SubArchType *sub_arch_type,
        ZigLLVM_VendorType *vendor_type, ZigLLVM_OSType *os_type, ZigLLVM_EnvironmentType *environ_type,
        ZigLLVM_ObjectFormatType *oformat)
{
    char *native_triple = LLVMGetDefaultTargetTriple();
    Triple triple(native_triple);

    *arch_type = (ZigLLVM_ArchType)triple.getArch();
    *sub_arch_type = (ZigLLVM_SubArchType)triple.getSubArch();
    *vendor_type = (ZigLLVM_VendorType)triple.getVendor();
    *os_type = (ZigLLVM_OSType)triple.getOS();
    *environ_type = (ZigLLVM_EnvironmentType)triple.getEnvironment();
    *oformat = (ZigLLVM_ObjectFormatType)triple.getObjectFormat();

    free(native_triple);
}

const char *ZigLLVMGetSubArchTypeName(ZigLLVM_SubArchType sub_arch) {
    switch (sub_arch) {
        case ZigLLVM_NoSubArch:
            return "(none)";
        case ZigLLVM_ARMSubArch_v8_1a:
            return "v8_1a";
        case ZigLLVM_ARMSubArch_v8:
            return "v8";
        case ZigLLVM_ARMSubArch_v7:
            return "v7";
        case ZigLLVM_ARMSubArch_v7em:
            return "v7em";
        case ZigLLVM_ARMSubArch_v7m:
            return "v7m";
        case ZigLLVM_ARMSubArch_v7s:
            return "v7s";
        case ZigLLVM_ARMSubArch_v6:
            return "v6";
        case ZigLLVM_ARMSubArch_v6m:
            return "v6m";
        case ZigLLVM_ARMSubArch_v6k:
            return "v6k";
        case ZigLLVM_ARMSubArch_v6t2:
            return "v6t2";
        case ZigLLVM_ARMSubArch_v5:
            return "v5";
        case ZigLLVM_ARMSubArch_v5te:
            return "v5te";
        case ZigLLVM_ARMSubArch_v4t:
            return "v4t";
        case ZigLLVM_KalimbaSubArch_v3:
            return "v3";
        case ZigLLVM_KalimbaSubArch_v4:
            return "v4";
        case ZigLLVM_KalimbaSubArch_v5:
            return "v5";
    }
    abort();
}

//------------------------------------

#include "buffer.hpp"

void ZigLLVMGetTargetTriple(Buf *out_buf, ZigLLVM_ArchType arch_type, ZigLLVM_SubArchType sub_arch_type,
        ZigLLVM_VendorType vendor_type, ZigLLVM_OSType os_type, ZigLLVM_EnvironmentType environ_type,
        ZigLLVM_ObjectFormatType oformat)
{
    Triple triple;

    triple.setArch((Triple::ArchType)arch_type);
    // TODO how to set the sub arch?
    triple.setVendor((Triple::VendorType)vendor_type);
    triple.setOS((Triple::OSType)os_type);
    triple.setEnvironment((Triple::EnvironmentType)environ_type);
    triple.setObjectFormat((Triple::ObjectFormatType)oformat);

    const std::string &str = triple.str();
    buf_init_from_mem(out_buf, str.c_str(), str.size());
}

enum FloatAbi {
    FloatAbiHard,
    FloatAbiSoft,
    FloatAbiSoftFp,
};

static int get_arm_sub_arch_version(const Triple &triple) {
    return ARMTargetParser::parseArchVersion(triple.getArchName());
}

static FloatAbi get_float_abi(const Triple &triple) {
    switch (triple.getOS()) {
        case Triple::Darwin:
        case Triple::MacOSX:
        case Triple::IOS:
            if (get_arm_sub_arch_version(triple) == 6 ||
                get_arm_sub_arch_version(triple) == 7)
            {
                return FloatAbiSoftFp;
            } else {
                return FloatAbiSoft;
            }
        case Triple::Win32:
            return FloatAbiHard;
        case Triple::FreeBSD:
            switch (triple.getEnvironment()) {
                case Triple::GNUEABIHF:
                    return FloatAbiHard;
                default:
                    return FloatAbiSoft;
            }
        default:
            switch (triple.getEnvironment()) {
                case Triple::GNUEABIHF:
                    return FloatAbiHard;
                case Triple::GNUEABI:
                    return FloatAbiSoftFp;
                case Triple::EABIHF:
                    return FloatAbiHard;
                case Triple::EABI:
                    return FloatAbiSoftFp;
                case Triple::Android:
                    if (get_arm_sub_arch_version(triple) == 7) {
                        return FloatAbiSoftFp;
                    } else {
                        return FloatAbiSoft;
                    }
                default:
                    return FloatAbiSoft;
            }
    }
}

Buf *get_dynamic_linker(LLVMTargetMachineRef target_machine_ref) {
    TargetMachine *target_machine = reinterpret_cast<TargetMachine*>(target_machine_ref);
    const Triple &triple = target_machine->getTargetTriple();

    const Triple::ArchType arch = triple.getArch();

    if (triple.getEnvironment() == Triple::Android) {
        if (triple.isArch64Bit()) {
            return buf_create_from_str("/system/bin/linker64");
        } else {
            return buf_create_from_str("/system/bin/linker");
        }
    } else if (arch == Triple::x86 ||
            arch == Triple::sparc ||
            arch == Triple::sparcel)
    {
        return buf_create_from_str("/lib/ld-linux.so.2");
    } else if (arch == Triple::aarch64) {
        return buf_create_from_str("/lib/ld-linux-aarch64.so.1");
    } else if (arch == Triple::aarch64_be) {
        return buf_create_from_str("/lib/ld-linux-aarch64_be.so.1");
    } else if (arch == Triple::arm || arch == Triple::thumb) {
        if (triple.getEnvironment() == Triple::GNUEABIHF ||
            get_float_abi(triple) == FloatAbiHard)
        {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == Triple::armeb || arch == Triple::thumbeb) {
        if (triple.getEnvironment() == Triple::GNUEABIHF ||
            get_float_abi(triple) == FloatAbiHard)
        {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == Triple::mips || arch == Triple::mipsel ||
            arch == Triple::mips64 || arch == Triple::mips64el)
    {
        // when you want to solve this TODO, grep clang codebase for
        // getLinuxDynamicLinker
        zig_panic("TODO figure out MIPS dynamic linker name");
    } else if (arch == Triple::ppc) {
        return buf_create_from_str("/lib/ld.so.1");
    } else if (arch == Triple::ppc64) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == Triple::ppc64le) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == Triple::systemz) {
        return buf_create_from_str("/lib64/ld64.so.1");
    } else if (arch == Triple::sparcv9) {
        return buf_create_from_str("/lib64/ld-linux.so.2");
    } else if (arch == Triple::x86_64 &&
            triple.getEnvironment() == Triple::GNUX32)
    {
        return buf_create_from_str("/libx32/ld-linux-x32.so.2");
    } else {
        return buf_create_from_str("/lib64/ld-linux-x86-64.so.2");
    }
}

