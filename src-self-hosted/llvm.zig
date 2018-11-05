const builtin = @import("builtin");
const c = @import("c.zig");
const assert = @import("std").debug.assert;

// we wrap the c module for 3 reasons:
// 1. to avoid accidentally calling the non-thread-safe functions
// 2. patch up some of the types to remove nullability
// 3. some functions have been augmented by zig_llvm.cpp to be more powerful,
//    such as ZigLLVMTargetMachineEmitToFile

pub const AttributeIndex = c_uint;
pub const Bool = c_int;

pub const BuilderRef = removeNullability(c.LLVMBuilderRef);
pub const ContextRef = removeNullability(c.LLVMContextRef);
pub const ModuleRef = removeNullability(c.LLVMModuleRef);
pub const ValueRef = removeNullability(c.LLVMValueRef);
pub const TypeRef = removeNullability(c.LLVMTypeRef);
pub const BasicBlockRef = removeNullability(c.LLVMBasicBlockRef);
pub const AttributeRef = removeNullability(c.LLVMAttributeRef);
pub const TargetRef = removeNullability(c.LLVMTargetRef);
pub const TargetMachineRef = removeNullability(c.LLVMTargetMachineRef);
pub const TargetDataRef = removeNullability(c.LLVMTargetDataRef);
pub const DIBuilder = c.ZigLLVMDIBuilder;

pub const ABIAlignmentOfType = c.LLVMABIAlignmentOfType;
pub const AddAttributeAtIndex = c.LLVMAddAttributeAtIndex;
pub const AddFunction = c.LLVMAddFunction;
pub const AddGlobal = c.LLVMAddGlobal;
pub const AddModuleCodeViewFlag = c.ZigLLVMAddModuleCodeViewFlag;
pub const AddModuleDebugInfoFlag = c.ZigLLVMAddModuleDebugInfoFlag;
pub const ArrayType = c.LLVMArrayType;
pub const BuildLoad = c.LLVMBuildLoad;
pub const ClearCurrentDebugLocation = c.ZigLLVMClearCurrentDebugLocation;
pub const ConstAllOnes = c.LLVMConstAllOnes;
pub const ConstArray = c.LLVMConstArray;
pub const ConstBitCast = c.LLVMConstBitCast;
pub const ConstInt = c.LLVMConstInt;
pub const ConstIntOfArbitraryPrecision = c.LLVMConstIntOfArbitraryPrecision;
pub const ConstNeg = c.LLVMConstNeg;
pub const ConstNull = c.LLVMConstNull;
pub const ConstStringInContext = c.LLVMConstStringInContext;
pub const ConstStructInContext = c.LLVMConstStructInContext;
pub const CopyStringRepOfTargetData = c.LLVMCopyStringRepOfTargetData;
pub const CreateBuilderInContext = c.LLVMCreateBuilderInContext;
pub const CreateCompileUnit = c.ZigLLVMCreateCompileUnit;
pub const CreateDIBuilder = c.ZigLLVMCreateDIBuilder;
pub const CreateEnumAttribute = c.LLVMCreateEnumAttribute;
pub const CreateFile = c.ZigLLVMCreateFile;
pub const CreateStringAttribute = c.LLVMCreateStringAttribute;
pub const CreateTargetDataLayout = c.LLVMCreateTargetDataLayout;
pub const CreateTargetMachine = c.LLVMCreateTargetMachine;
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
pub const GetHostCPUName = c.ZigLLVMGetHostCPUName;
pub const GetMDKindIDInContext = c.LLVMGetMDKindIDInContext;
pub const GetNativeFeatures = c.ZigLLVMGetNativeFeatures;
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
pub const IntTypeInContext = c.LLVMIntTypeInContext;
pub const LabelTypeInContext = c.LLVMLabelTypeInContext;
pub const MDNodeInContext = c.LLVMMDNodeInContext;
pub const MDStringInContext = c.LLVMMDStringInContext;
pub const MetadataTypeInContext = c.LLVMMetadataTypeInContext;
pub const ModuleCreateWithNameInContext = c.LLVMModuleCreateWithNameInContext;
pub const PPCFP128TypeInContext = c.LLVMPPCFP128TypeInContext;
pub const PointerType = c.LLVMPointerType;
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
pub const VoidTypeInContext = c.LLVMVoidTypeInContext;
pub const X86FP80TypeInContext = c.LLVMX86FP80TypeInContext;
pub const X86MMXTypeInContext = c.LLVMX86MMXTypeInContext;

pub const GetElementType = LLVMGetElementType;
extern fn LLVMGetElementType(Ty: TypeRef) TypeRef;

pub const TypeOf = LLVMTypeOf;
extern fn LLVMTypeOf(Val: ValueRef) TypeRef;

pub const BuildStore = LLVMBuildStore;
extern fn LLVMBuildStore(arg0: BuilderRef, Val: ValueRef, Ptr: ValueRef) ?ValueRef;

pub const BuildAlloca = LLVMBuildAlloca;
extern fn LLVMBuildAlloca(arg0: BuilderRef, Ty: TypeRef, Name: ?[*]const u8) ?ValueRef;

pub const ConstInBoundsGEP = LLVMConstInBoundsGEP;
pub extern fn LLVMConstInBoundsGEP(ConstantVal: ValueRef, ConstantIndices: [*]ValueRef, NumIndices: c_uint) ?ValueRef;

pub const GetTargetFromTriple = LLVMGetTargetFromTriple;
extern fn LLVMGetTargetFromTriple(Triple: [*]const u8, T: *TargetRef, ErrorMessage: ?*[*]u8) Bool;

pub const VerifyModule = LLVMVerifyModule;
extern fn LLVMVerifyModule(M: ModuleRef, Action: VerifierFailureAction, OutMessage: *?[*]u8) Bool;

pub const GetInsertBlock = LLVMGetInsertBlock;
extern fn LLVMGetInsertBlock(Builder: BuilderRef) BasicBlockRef;

pub const FunctionType = LLVMFunctionType;
extern fn LLVMFunctionType(
    ReturnType: TypeRef,
    ParamTypes: [*]TypeRef,
    ParamCount: c_uint,
    IsVarArg: Bool,
) ?TypeRef;

pub const GetParam = LLVMGetParam;
extern fn LLVMGetParam(Fn: ValueRef, Index: c_uint) ValueRef;

pub const AppendBasicBlockInContext = LLVMAppendBasicBlockInContext;
extern fn LLVMAppendBasicBlockInContext(C: ContextRef, Fn: ValueRef, Name: [*]const u8) ?BasicBlockRef;

pub const PositionBuilderAtEnd = LLVMPositionBuilderAtEnd;
extern fn LLVMPositionBuilderAtEnd(Builder: BuilderRef, Block: BasicBlockRef) void;

pub const AbortProcessAction = VerifierFailureAction.LLVMAbortProcessAction;
pub const PrintMessageAction = VerifierFailureAction.LLVMPrintMessageAction;
pub const ReturnStatusAction = VerifierFailureAction.LLVMReturnStatusAction;
pub const VerifierFailureAction = c.LLVMVerifierFailureAction;

pub const CodeGenLevelNone = c.LLVMCodeGenOptLevel.LLVMCodeGenLevelNone;
pub const CodeGenLevelLess = c.LLVMCodeGenOptLevel.LLVMCodeGenLevelLess;
pub const CodeGenLevelDefault = c.LLVMCodeGenOptLevel.LLVMCodeGenLevelDefault;
pub const CodeGenLevelAggressive = c.LLVMCodeGenOptLevel.LLVMCodeGenLevelAggressive;
pub const CodeGenOptLevel = c.LLVMCodeGenOptLevel;

pub const RelocDefault = c.LLVMRelocMode.LLVMRelocDefault;
pub const RelocStatic = c.LLVMRelocMode.LLVMRelocStatic;
pub const RelocPIC = c.LLVMRelocMode.LLVMRelocPIC;
pub const RelocDynamicNoPic = c.LLVMRelocMode.LLVMRelocDynamicNoPic;
pub const RelocMode = c.LLVMRelocMode;

pub const CodeModelDefault = c.LLVMCodeModel.LLVMCodeModelDefault;
pub const CodeModelJITDefault = c.LLVMCodeModel.LLVMCodeModelJITDefault;
pub const CodeModelSmall = c.LLVMCodeModel.LLVMCodeModelSmall;
pub const CodeModelKernel = c.LLVMCodeModel.LLVMCodeModelKernel;
pub const CodeModelMedium = c.LLVMCodeModel.LLVMCodeModelMedium;
pub const CodeModelLarge = c.LLVMCodeModel.LLVMCodeModelLarge;
pub const CodeModel = c.LLVMCodeModel;

pub const EmitAssembly = EmitOutputType.ZigLLVM_EmitAssembly;
pub const EmitBinary = EmitOutputType.ZigLLVM_EmitBinary;
pub const EmitLLVMIr = EmitOutputType.ZigLLVM_EmitLLVMIr;
pub const EmitOutputType = c.ZigLLVM_EmitOutputType;

pub const CCallConv = c.LLVMCCallConv;
pub const FastCallConv = c.LLVMFastCallConv;
pub const ColdCallConv = c.LLVMColdCallConv;
pub const WebKitJSCallConv = c.LLVMWebKitJSCallConv;
pub const AnyRegCallConv = c.LLVMAnyRegCallConv;
pub const X86StdcallCallConv = c.LLVMX86StdcallCallConv;
pub const X86FastcallCallConv = c.LLVMX86FastcallCallConv;
pub const CallConv = c.LLVMCallConv;

pub const FnInline = extern enum.{
    Auto,
    Always,
    Never,
};

fn removeNullability(comptime T: type) type {
    comptime assert(@typeId(T) == builtin.TypeId.Optional);
    return T.Child;
}

pub const BuildRet = LLVMBuildRet;
extern fn LLVMBuildRet(arg0: BuilderRef, V: ?ValueRef) ?ValueRef;

pub const TargetMachineEmitToFile = ZigLLVMTargetMachineEmitToFile;
extern fn ZigLLVMTargetMachineEmitToFile(
    targ_machine_ref: TargetMachineRef,
    module_ref: ModuleRef,
    filename: [*]const u8,
    output_type: EmitOutputType,
    error_message: *[*]u8,
    is_debug: bool,
    is_small: bool,
) bool;

pub const BuildCall = ZigLLVMBuildCall;
extern fn ZigLLVMBuildCall(B: BuilderRef, Fn: ValueRef, Args: [*]ValueRef, NumArgs: c_uint, CC: c_uint, fn_inline: FnInline, Name: [*]const u8) ?ValueRef;

pub const PrivateLinkage = c.LLVMLinkage.LLVMPrivateLinkage;
