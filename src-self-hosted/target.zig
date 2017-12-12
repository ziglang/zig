const c = @import("c.zig");

pub fn initializeAll() {
    c.LLVMInitializeAllTargets();
    c.LLVMInitializeAllTargetInfos();
    c.LLVMInitializeAllTargetMCs();
    c.LLVMInitializeAllAsmPrinters();
    c.LLVMInitializeAllAsmParsers();
}
