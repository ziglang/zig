const builtin = @import("builtin");
const c = @import("c.zig");
const assert = @import("std").debug.assert;

pub const AttributeIndex = c_uint;
pub const Bool = c_int;

pub const BuilderRef = removeNullability(c.LLVMBuilderRef);
pub const ContextRef = removeNullability(c.LLVMContextRef);
pub const ModuleRef = removeNullability(c.LLVMModuleRef);
pub const ValueRef = removeNullability(c.LLVMValueRef);
pub const TypeRef = removeNullability(c.LLVMTypeRef);
pub const BasicBlockRef = removeNullability(c.LLVMBasicBlockRef);
pub const AttributeRef = removeNullability(c.LLVMAttributeRef);

pub const AddAttributeAtIndex = c.LLVMAddAttributeAtIndex;
pub const AddFunction = c.LLVMAddFunction;
pub const ClearCurrentDebugLocation = c.ZigLLVMClearCurrentDebugLocation;
pub const ConstInt = c.LLVMConstInt;
pub const ConstStringInContext = c.LLVMConstStringInContext;
pub const ConstStructInContext = c.LLVMConstStructInContext;
pub const CreateBuilderInContext = c.LLVMCreateBuilderInContext;
pub const CreateEnumAttribute = c.LLVMCreateEnumAttribute;
pub const CreateStringAttribute = c.LLVMCreateStringAttribute;
pub const DisposeBuilder = c.LLVMDisposeBuilder;
pub const DisposeModule = c.LLVMDisposeModule;
pub const DoubleTypeInContext = c.LLVMDoubleTypeInContext;
pub const DumpModule = c.LLVMDumpModule;
pub const FP128TypeInContext = c.LLVMFP128TypeInContext;
pub const FloatTypeInContext = c.LLVMFloatTypeInContext;
pub const GetEnumAttributeKindForName = c.LLVMGetEnumAttributeKindForName;
pub const GetMDKindIDInContext = c.LLVMGetMDKindIDInContext;
pub const HalfTypeInContext = c.LLVMHalfTypeInContext;
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
pub const StructTypeInContext = c.LLVMStructTypeInContext;
pub const TokenTypeInContext = c.LLVMTokenTypeInContext;
pub const VoidTypeInContext = c.LLVMVoidTypeInContext;
pub const X86FP80TypeInContext = c.LLVMX86FP80TypeInContext;
pub const X86MMXTypeInContext = c.LLVMX86MMXTypeInContext;
pub const ConstAllOnes = c.LLVMConstAllOnes;
pub const ConstNull = c.LLVMConstNull;

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

fn removeNullability(comptime T: type) type {
    comptime assert(@typeId(T) == builtin.TypeId.Optional);
    return T.Child;
}

pub const BuildRet = LLVMBuildRet;
extern fn LLVMBuildRet(arg0: BuilderRef, V: ?ValueRef) ValueRef;
