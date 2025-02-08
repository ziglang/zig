// Mostly copied from llvm.zig
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);
const math = std.math;
const DW = std.dwarf;

//const Builder = @import("llvm/Builder.zig");
const gccjit = @import("gccjit/bindings.zig");
const link = @import("../link.zig");
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Package = @import("../Package.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Value = @import("../Value.zig");
const Type = @import("../Type.zig");
const x86_64_abi = @import("../arch/x86_64/abi.zig");
const wasm_c_abi = @import("../arch/wasm/abi.zig");
const aarch64_c_abi = @import("../arch/aarch64/abi.zig");
const arm_c_abi = @import("../arch/arm/abi.zig");
const riscv_c_abi = @import("../arch/riscv64/abi.zig");
const mips_c_abi = @import("../arch/mips/abi.zig");
const dev = @import("../dev.zig");

const Error = error{ OutOfMemory, CodegenFail };

pub fn getGCCJIT_Type_FromInst(inst: Air.Inst.Ref) c_int {
    switch (inst) {
        .c_long_type => {
            return gccjit.GCC_JIT_TYPE_LONG;
        },

        else => return 9,
    }
}
