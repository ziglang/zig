const c = @import("c.zig");
const assert = @import("std").debug.assert;

// we wrap the c module for 3 reasons:
// 1. to avoid accidentally calling the non-thread-safe functions
// 2. patch up some of the types to remove nullability
// 3. some functions have been augmented by zig_llvm.cpp to be more powerful,
//    such as ZigLLVMTargetMachineEmitToFile

pub const AttributeIndex = c_uint;
pub const Bool = c_int;

pub const Builder = c.LLVMBuilderRef.Child.Child;
pub const Context = c.LLVMContextRef.Child.Child;
pub const Module = c.LLVMModuleRef.Child.Child;
pub const Value = c.LLVMValueRef.Child.Child;
pub const Type = c.LLVMTypeRef.Child.Child;
pub const BasicBlock = c.LLVMBasicBlockRef.Child.Child;
pub const Attribute = c.LLVMAttributeRef.Child.Child;
pub const Target = c.LLVMTargetRef.Child.Child;
pub const TargetMachine = c.LLVMTargetMachineRef.Child.Child;
pub const TargetData = c.LLVMTargetDataRef.Child.Child;
pub const DIBuilder = c.ZigLLVMDIBuilder;
pub const DIFile = c.ZigLLVMDIFile;
pub const DICompileUnit = c.ZigLLVMDICompileUnit;

pub const ABIAlignmentOfType = c.LLVMABIAlignmentOfType;
pub const AddAttributeAtIndex = c.LLVMAddAttributeAtIndex;
pub const AddModuleCodeViewFlag = c.ZigLLVMAddModuleCodeViewFlag;
pub const AddModuleDebugInfoFlag = c.ZigLLVMAddModuleDebugInfoFlag;
pub const ClearCurrentDebugLocation = c.ZigLLVMClearCurrentDebugLocation;
pub const ConstAllOnes = c.LLVMConstAllOnes;
pub const ConstArray = c.LLVMConstArray;
pub const ConstBitCast = c.LLVMConstBitCast;
pub const ConstIntOfArbitraryPrecision = c.LLVMConstIntOfArbitraryPrecision;
pub const ConstNeg = c.LLVMConstNeg;
pub const ConstStructInContext = c.LLVMConstStructInContext;
pub const DIBuilderFinalize = c.ZigLLVMDIBuilderFinalize;
pub const DisposeBuilder = c.LLVMDisposeBuilder;
pub const DisposeDIBuilder = c.ZigLLVMDisposeDIBuilder;
pub const DisposeMessage = c.LLVMDisposeMessage;
pub const DisposeModule = c.LLVMDisposeModule;
pub const DisposeTargetData = c.LLVMDisposeTargetData;
pub const DisposeTargetMachine = c.LLVMDisposeTargetMachine;
pub const DoubleTypeInContext = c.LLVMDoubleTypeInContext;
pub const DumpModule = c.LLVMDumpModule;
pub const FP128TypeInContext = c.LLVMFP128TypeInContext;
pub const FloatTypeInContext = c.LLVMFloatTypeInContext;
pub const GetEnumAttributeKindForName = c.LLVMGetEnumAttributeKindForName;
pub const GetMDKindIDInContext = c.LLVMGetMDKindIDInContext;
pub const GetUndef = c.LLVMGetUndef;
pub const HalfTypeInContext = c.LLVMHalfTypeInContext;
pub const InitializeAllAsmParsers = c.LLVMInitializeAllAsmParsers;
pub const InitializeAllAsmPrinters = c.LLVMInitializeAllAsmPrinters;
pub const InitializeAllTargetInfos = c.LLVMInitializeAllTargetInfos;
pub const InitializeAllTargetMCs = c.LLVMInitializeAllTargetMCs;
pub const InitializeAllTargets = c.LLVMInitializeAllTargets;
pub const InsertBasicBlockInContext = c.LLVMInsertBasicBlockInContext;
pub const Int128TypeInContext = c.LLVMInt128TypeInContext;
pub const Int16TypeInContext = c.LLVMInt16TypeInContext;
pub const Int1TypeInContext = c.LLVMInt1TypeInContext;
pub const Int32TypeInContext = c.LLVMInt32TypeInContext;
pub const Int64TypeInContext = c.LLVMInt64TypeInContext;
pub const Int8TypeInContext = c.LLVMInt8TypeInContext;
pub const IntPtrTypeForASInContext = c.LLVMIntPtrTypeForASInContext;
pub const IntPtrTypeInContext = c.LLVMIntPtrTypeInContext;
pub const LabelTypeInContext = c.LLVMLabelTypeInContext;
pub const MDNodeInContext = c.LLVMMDNodeInContext;
pub const MDStringInContext = c.LLVMMDStringInContext;
pub const MetadataTypeInContext = c.LLVMMetadataTypeInContext;
pub const PPCFP128TypeInContext = c.LLVMPPCFP128TypeInContext;
pub const SetAlignment = c.LLVMSetAlignment;
pub const SetDataLayout = c.LLVMSetDataLayout;
pub const SetGlobalConstant = c.LLVMSetGlobalConstant;
pub const SetInitializer = c.LLVMSetInitializer;
pub const SetLinkage = c.LLVMSetLinkage;
pub const SetTarget = c.LLVMSetTarget;
pub const SetUnnamedAddr = c.LLVMSetUnnamedAddr;
pub const SetVolatile = c.LLVMSetVolatile;
pub const StructTypeInContext = c.LLVMStructTypeInContext;
pub const TokenTypeInContext = c.LLVMTokenTypeInContext;
pub const X86FP80TypeInContext = c.LLVMX86FP80TypeInContext;
pub const X86MMXTypeInContext = c.LLVMX86MMXTypeInContext;

pub const AddGlobal = LLVMAddGlobal;
extern fn LLVMAddGlobal(M: *Module, Ty: *Type, Name: [*:0]const u8) ?*Value;

pub const ConstStringInContext = LLVMConstStringInContext;
extern fn LLVMConstStringInContext(C: *Context, Str: [*]const u8, Length: c_uint, DontNullTerminate: Bool) ?*Value;

pub const ConstInt = LLVMConstInt;
extern fn LLVMConstInt(IntTy: *Type, N: c_ulonglong, SignExtend: Bool) ?*Value;

pub const BuildLoad = LLVMBuildLoad;
extern fn LLVMBuildLoad(arg0: *Builder, PointerVal: *Value, Name: [*:0]const u8) ?*Value;

pub const ConstNull = LLVMConstNull;
extern fn LLVMConstNull(Ty: *Type) ?*Value;

pub const CreateStringAttribute = LLVMCreateStringAttribute;
extern fn LLVMCreateStringAttribute(
    C: *Context,
    K: [*]const u8,
    KLength: c_uint,
    V: [*]const u8,
    VLength: c_uint,
) ?*Attribute;

pub const CreateEnumAttribute = LLVMCreateEnumAttribute;
extern fn LLVMCreateEnumAttribute(C: *Context, KindID: c_uint, Val: u64) ?*Attribute;

pub const AddFunction = LLVMAddFunction;
extern fn LLVMAddFunction(M: *Module, Name: [*:0]const u8, FunctionTy: *Type) ?*Value;

pub const CreateCompileUnit = ZigLLVMCreateCompileUnit;
extern fn ZigLLVMCreateCompileUnit(
    dibuilder: *DIBuilder,
    lang: c_uint,
    difile: *DIFile,
    producer: [*:0]const u8,
    is_optimized: bool,
    flags: [*:0]const u8,
    runtime_version: c_uint,
    split_name: [*:0]const u8,
    dwo_id: u64,
    emit_debug_info: bool,
) ?*DICompileUnit;

pub const CreateFile = ZigLLVMCreateFile;
extern fn ZigLLVMCreateFile(dibuilder: *DIBuilder, filename: [*:0]const u8, directory: [*:0]const u8) ?*DIFile;

pub const ArrayType = LLVMArrayType;
extern fn LLVMArrayType(ElementType: *Type, ElementCount: c_uint) ?*Type;

pub const CreateDIBuilder = ZigLLVMCreateDIBuilder;
extern fn ZigLLVMCreateDIBuilder(module: *Module, allow_unresolved: bool) ?*DIBuilder;

pub const PointerType = LLVMPointerType;
extern fn LLVMPointerType(ElementType: *Type, AddressSpace: c_uint) ?*Type;

pub const CreateBuilderInContext = LLVMCreateBuilderInContext;
extern fn LLVMCreateBuilderInContext(C: *Context) ?*Builder;

pub const IntTypeInContext = LLVMIntTypeInContext;
extern fn LLVMIntTypeInContext(C: *Context, NumBits: c_uint) ?*Type;

pub const ModuleCreateWithNameInContext = LLVMModuleCreateWithNameInContext;
extern fn LLVMModuleCreateWithNameInContext(ModuleID: [*:0]const u8, C: *Context) ?*Module;

pub const VoidTypeInContext = LLVMVoidTypeInContext;
extern fn LLVMVoidTypeInContext(C: *Context) ?*Type;

pub const ContextCreate = LLVMContextCreate;
extern fn LLVMContextCreate() ?*Context;

pub const ContextDispose = LLVMContextDispose;
extern fn LLVMContextDispose(C: *Context) void;

pub const CopyStringRepOfTargetData = LLVMCopyStringRepOfTargetData;
extern fn LLVMCopyStringRepOfTargetData(TD: *TargetData) ?[*:0]u8;

pub const CreateTargetDataLayout = LLVMCreateTargetDataLayout;
extern fn LLVMCreateTargetDataLayout(T: *TargetMachine) ?*TargetData;

pub const CreateTargetMachine = ZigLLVMCreateTargetMachine;
extern fn ZigLLVMCreateTargetMachine(
    T: *Target,
    Triple: [*:0]const u8,
    CPU: [*:0]const u8,
    Features: [*:0]const u8,
    Level: CodeGenOptLevel,
    Reloc: RelocMode,
    CodeModel: CodeModel,
    function_sections: bool,
) ?*TargetMachine;

pub const GetHostCPUName = LLVMGetHostCPUName;
extern fn LLVMGetHostCPUName() ?[*:0]u8;

pub const GetNativeFeatures = ZigLLVMGetNativeFeatures;
extern fn ZigLLVMGetNativeFeatures() ?[*:0]u8;

pub const GetElementType = LLVMGetElementType;
extern fn LLVMGetElementType(Ty: *Type) *Type;

pub const TypeOf = LLVMTypeOf;
extern fn LLVMTypeOf(Val: *Value) *Type;

pub const BuildStore = LLVMBuildStore;
extern fn LLVMBuildStore(arg0: *Builder, Val: *Value, Ptr: *Value) ?*Value;

pub const BuildAlloca = LLVMBuildAlloca;
extern fn LLVMBuildAlloca(arg0: *Builder, Ty: *Type, Name: ?[*:0]const u8) ?*Value;

pub const ConstInBoundsGEP = LLVMConstInBoundsGEP;
pub extern fn LLVMConstInBoundsGEP(ConstantVal: *Value, ConstantIndices: [*]*Value, NumIndices: c_uint) ?*Value;

pub const GetTargetFromTriple = LLVMGetTargetFromTriple;
extern fn LLVMGetTargetFromTriple(Triple: [*:0]const u8, T: **Target, ErrorMessage: ?*[*:0]u8) Bool;

pub const VerifyModule = LLVMVerifyModule;
extern fn LLVMVerifyModule(M: *Module, Action: VerifierFailureAction, OutMessage: *?[*:0]u8) Bool;

pub const GetInsertBlock = LLVMGetInsertBlock;
extern fn LLVMGetInsertBlock(Builder: *Builder) *BasicBlock;

pub const FunctionType = LLVMFunctionType;
extern fn LLVMFunctionType(
    ReturnType: *Type,
    ParamTypes: [*]*Type,
    ParamCount: c_uint,
    IsVarArg: Bool,
) ?*Type;

pub const GetParam = LLVMGetParam;
extern fn LLVMGetParam(Fn: *Value, Index: c_uint) *Value;

pub const AppendBasicBlockInContext = LLVMAppendBasicBlockInContext;
extern fn LLVMAppendBasicBlockInContext(C: *Context, Fn: *Value, Name: [*:0]const u8) ?*BasicBlock;

pub const PositionBuilderAtEnd = LLVMPositionBuilderAtEnd;
extern fn LLVMPositionBuilderAtEnd(Builder: *Builder, Block: *BasicBlock) void;

pub const AbortProcessAction = VerifierFailureAction.LLVMAbortProcessAction;
pub const PrintMessageAction = VerifierFailureAction.LLVMPrintMessageAction;
pub const ReturnStatusAction = VerifierFailureAction.LLVMReturnStatusAction;
pub const VerifierFailureAction = c.LLVMVerifierFailureAction;

pub const CodeGenLevelNone = CodeGenOptLevel.LLVMCodeGenLevelNone;
pub const CodeGenLevelLess = CodeGenOptLevel.LLVMCodeGenLevelLess;
pub const CodeGenLevelDefault = CodeGenOptLevel.LLVMCodeGenLevelDefault;
pub const CodeGenLevelAggressive = CodeGenOptLevel.LLVMCodeGenLevelAggressive;
pub const CodeGenOptLevel = c.LLVMCodeGenOptLevel;

pub const RelocDefault = RelocMode.LLVMRelocDefault;
pub const RelocStatic = RelocMode.LLVMRelocStatic;
pub const RelocPIC = RelocMode.LLVMRelocPIC;
pub const RelocDynamicNoPic = RelocMode.LLVMRelocDynamicNoPic;
pub const RelocMode = c.LLVMRelocMode;

pub const CodeModelDefault = CodeModel.LLVMCodeModelDefault;
pub const CodeModelJITDefault = CodeModel.LLVMCodeModelJITDefault;
pub const CodeModelSmall = CodeModel.LLVMCodeModelSmall;
pub const CodeModelKernel = CodeModel.LLVMCodeModelKernel;
pub const CodeModelMedium = CodeModel.LLVMCodeModelMedium;
pub const CodeModelLarge = CodeModel.LLVMCodeModelLarge;
pub const CodeModel = c.LLVMCodeModel;

pub const EmitAssembly = EmitOutputType.ZigLLVM_EmitAssembly;
pub const EmitBinary = EmitOutputType.ZigLLVM_EmitBinary;
pub const EmitLLVMIr = EmitOutputType.ZigLLVM_EmitLLVMIr;
pub const EmitOutputType = c.ZigLLVM_EmitOutputType;

pub const CCallConv = CallConv.LLVMCCallConv;
pub const FastCallConv = CallConv.LLVMFastCallConv;
pub const ColdCallConv = CallConv.LLVMColdCallConv;
pub const WebKitJSCallConv = CallConv.LLVMWebKitJSCallConv;
pub const AnyRegCallConv = CallConv.LLVMAnyRegCallConv;
pub const X86StdcallCallConv = CallConv.LLVMX86StdcallCallConv;
pub const X86FastcallCallConv = CallConv.LLVMX86FastcallCallConv;
pub const CallConv = c.LLVMCallConv;

pub const CallAttr = extern enum {
    Auto,
    NeverTail,
    NeverInline,
    AlwaysTail,
    AlwaysInline,
};

fn removeNullability(comptime T: type) type {
    comptime assert(@typeInfo(T).Pointer.size == .C);
    return *T.Child;
}

pub const BuildRet = LLVMBuildRet;
extern fn LLVMBuildRet(arg0: *Builder, V: ?*Value) ?*Value;

pub const TargetMachineEmitToFile = ZigLLVMTargetMachineEmitToFile;
extern fn ZigLLVMTargetMachineEmitToFile(
    targ_machine_ref: *TargetMachine,
    module_ref: *Module,
    filename: [*:0]const u8,
    output_type: EmitOutputType,
    error_message: *[*:0]u8,
    is_debug: bool,
    is_small: bool,
) bool;

pub const BuildCall = ZigLLVMBuildCall;
extern fn ZigLLVMBuildCall(B: *Builder, Fn: *Value, Args: [*]*Value, NumArgs: c_uint, CC: CallConv, fn_inline: CallAttr, Name: [*:0]const u8) ?*Value;

pub const PrivateLinkage = c.LLVMLinkage.LLVMPrivateLinkage;
