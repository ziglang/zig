const std = @import("std");

const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");

pub fn buildWASILibcSysroot(comp: *Compilation) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    return error.TODOBuildWASILibcSysroot;
}
