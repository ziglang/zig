const std = @import("std");
const Target = std.Target;
const llvm = @import("llvm.zig");

pub fn getDarwinArchString(self: Target) [:0]const u8 {
    const arch = self.getArch();
    switch (arch) {
        .aarch64 => return "arm64",
        .thumb,
        .arm,
        => return "arm",
        .powerpc => return "ppc",
        .powerpc64 => return "ppc64",
        .powerpc64le => return "ppc64le",
        // @tagName should be able to return sentinel terminated slice
        else => @panic("TODO https://github.com/ziglang/zig/issues/3779"), //return @tagName(arch),
    }
}

pub fn llvmTargetFromTriple(triple: std.Buffer) !*llvm.Target {
    var result: *llvm.Target = undefined;
    var err_msg: [*:0]u8 = undefined;
    if (llvm.GetTargetFromTriple(triple.toSlice(), &result, &err_msg) != 0) {
        std.debug.warn("triple: {s} error: {s}\n", .{ triple.toSlice(), err_msg });
        return error.UnsupportedTarget;
    }
    return result;
}

pub fn initializeAllTargets() void {
    llvm.InitializeAllTargets();
    llvm.InitializeAllTargetInfos();
    llvm.InitializeAllTargetMCs();
    llvm.InitializeAllAsmPrinters();
    llvm.InitializeAllAsmParsers();
}

pub fn getTriple(allocator: *std.mem.Allocator, self: std.Target) !std.Buffer {
    var result = try std.Buffer.initSize(allocator, 0);
    errdefer result.deinit();

    // LLVM WebAssembly output support requires the target to be activated at
    // build type with -DCMAKE_LLVM_EXPIERMENTAL_TARGETS_TO_BUILD=WebAssembly.
    //
    // LLVM determines the output format based on the abi suffix,
    // defaulting to an object based on the architecture. The default format in
    // LLVM 6 sets the wasm arch output incorrectly to ELF. We need to
    // explicitly set this ourself in order for it to work.
    //
    // This is fixed in LLVM 7 and you will be able to get wasm output by
    // using the target triple `wasm32-unknown-unknown-unknown`.
    const env_name = if (self.isWasm()) "wasm" else @tagName(self.getAbi());

    var out = &std.io.BufferOutStream.init(&result).stream;
    try out.print("{}-unknown-{}-{}", .{ @tagName(self.getArch()), @tagName(self.getOs()), env_name });

    return result;
}
