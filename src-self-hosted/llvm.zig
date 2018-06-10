const builtin = @import("builtin");
const c = @import("c.zig");
const assert = @import("std").debug.assert;

pub const ValueRef = removeNullability(c.LLVMValueRef);
pub const ModuleRef = removeNullability(c.LLVMModuleRef);
pub const ContextRef = removeNullability(c.LLVMContextRef);
pub const BuilderRef = removeNullability(c.LLVMBuilderRef);

fn removeNullability(comptime T: type) type {
    comptime assert(@typeId(T) == builtin.TypeId.Optional);
    return T.Child;
}
