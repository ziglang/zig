const builtin = @import("builtin");
const c = @import("c.zig");
const assert = @import("std").debug.assert;

pub const BuilderRef = removeNullability(c.LLVMBuilderRef);
pub const ContextRef = removeNullability(c.LLVMContextRef);
pub const ModuleRef = removeNullability(c.LLVMModuleRef);
pub const ValueRef = removeNullability(c.LLVMValueRef);
pub const TypeRef = removeNullability(c.LLVMTypeRef);

pub const AddFunction = c.LLVMAddFunction;
pub const CreateBuilderInContext = c.LLVMCreateBuilderInContext;
pub const DisposeBuilder = c.LLVMDisposeBuilder;
pub const DisposeModule = c.LLVMDisposeModule;
pub const DumpModule = c.LLVMDumpModule;
pub const ModuleCreateWithNameInContext = c.LLVMModuleCreateWithNameInContext;
pub const VoidTypeInContext = c.LLVMVoidTypeInContext;

pub const FunctionType = LLVMFunctionType;
extern fn LLVMFunctionType(
    ReturnType: TypeRef,
    ParamTypes: [*]TypeRef,
    ParamCount: c_uint,
    IsVarArg: c_int,
) ?TypeRef;

fn removeNullability(comptime T: type) type {
    comptime assert(@typeId(T) == builtin.TypeId.Optional);
    return T.Child;
}
