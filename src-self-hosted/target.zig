const std = @import("std");
const builtin = @import("builtin");
const llvm = @import("llvm.zig");

pub const Target = union(enum) {
    Native,
    Cross: Cross,

    pub const Cross = struct {
        arch: builtin.Arch,
        os: builtin.Os,
        environ: builtin.Environ,
        object_format: builtin.ObjectFormat,
    };

    pub fn oFileExt(self: Target) []const u8 {
        return switch (self.getObjectFormat()) {
            builtin.ObjectFormat.coff => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: Target) []const u8 {
        return switch (self.getOs()) {
            builtin.Os.windows => ".exe",
            else => "",
        };
    }

    pub fn getOs(self: Target) builtin.Os {
        return switch (self) {
            Target.Native => builtin.os,
            @TagType(Target).Cross => |t| t.os,
        };
    }

    pub fn getArch(self: Target) builtin.Arch {
        return switch (self) {
            Target.Native => builtin.arch,
            @TagType(Target).Cross => |t| t.arch,
        };
    }

    pub fn getEnviron(self: Target) builtin.Environ {
        return switch (self) {
            Target.Native => builtin.environ,
            @TagType(Target).Cross => |t| t.environ,
        };
    }

    pub fn getObjectFormat(self: Target) builtin.ObjectFormat {
        return switch (self) {
            Target.Native => builtin.object_format,
            @TagType(Target).Cross => |t| t.object_format,
        };
    }

    pub fn isWasm(self: Target) bool {
        return switch (self.getArch()) {
            builtin.Arch.wasm32, builtin.Arch.wasm64 => true,
            else => false,
        };
    }

    pub fn isDarwin(self: Target) bool {
        return switch (self.getOs()) {
            builtin.Os.ios, builtin.Os.macosx => true,
            else => false,
        };
    }

    pub fn isWindows(self: Target) bool {
        return switch (self.getOs()) {
            builtin.Os.windows => true,
            else => false,
        };
    }

    pub fn initializeAll() void {
        llvm.InitializeAllTargets();
        llvm.InitializeAllTargetInfos();
        llvm.InitializeAllTargetMCs();
        llvm.InitializeAllAsmPrinters();
        llvm.InitializeAllAsmParsers();
    }

    pub fn getTriple(self: Target, allocator: *std.mem.Allocator) !std.Buffer {
        var result = try std.Buffer.initSize(allocator, 0);
        errdefer result.deinit();

        // LLVM WebAssembly output support requires the target to be activated at
        // build type with -DCMAKE_LLVM_EXPIERMENTAL_TARGETS_TO_BUILD=WebAssembly.
        //
        // LLVM determines the output format based on the environment suffix,
        // defaulting to an object based on the architecture. The default format in
        // LLVM 6 sets the wasm arch output incorrectly to ELF. We need to
        // explicitly set this ourself in order for it to work.
        //
        // This is fixed in LLVM 7 and you will be able to get wasm output by
        // using the target triple `wasm32-unknown-unknown-unknown`.
        const env_name = if (self.isWasm()) "wasm" else @tagName(self.getEnviron());

        var out = &std.io.BufferOutStream.init(&result).stream;
        try out.print("{}-unknown-{}-{}", @tagName(self.getArch()), @tagName(self.getOs()), env_name);

        return result;
    }

    pub fn llvmTargetFromTriple(triple: std.Buffer) !llvm.TargetRef {
        var result: llvm.TargetRef = undefined;
        var err_msg: [*]u8 = undefined;
        if (llvm.GetTargetFromTriple(triple.ptr(), &result, &err_msg) != 0) {
            std.debug.warn("triple: {s} error: {s}\n", triple.ptr(), err_msg);
            return error.UnsupportedTarget;
        }
        return result;
    }
};
