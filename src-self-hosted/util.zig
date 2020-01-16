const std = @import("std");
const Target = std.Target;
const llvm = @import("llvm.zig");

pub const FloatAbi = enum {
    Hard,
    Soft,
    SoftFp,
};

/// TODO expose the arch and subarch separately
pub fn isArmOrThumb(self: Target) bool {
    return switch (self.getArch()) {
        .arm,
        .armeb,
        .aarch64,
        .aarch64_be,
        .thumb,
        .thumbeb,
        => true,
        else => false,
    };
}

pub fn getFloatAbi(self: Target) FloatAbi {
    return switch (self.getAbi()) {
        .gnueabihf,
        .eabihf,
        .musleabihf,
        => .Hard,
        else => .Soft,
    };
}

pub fn getObjectFormat(target: Target) Target.ObjectFormat {
    switch (target) {
        .Native => return @import("builtin").object_format,
        .Cross => blk: {
            if (target.isWindows() or target.isUefi()) {
                return .coff;
            } else if (target.isDarwin()) {
                return .macho;
            }
            if (target.isWasm()) {
                return .wasm;
            }
            return .elf;
        },
    }
}

pub fn getDynamicLinkerPath(self: Target) ?[]const u8 {
    const env = self.getAbi();
    const arch = self.getArch();
    const os = self.getOs();
    switch (os) {
        .freebsd => {
            return "/libexec/ld-elf.so.1";
        },
        .linux => {
            switch (env) {
                .android => {
                    if (self.getArchPtrBitWidth() == 64) {
                        return "/system/bin/linker64";
                    } else {
                        return "/system/bin/linker";
                    }
                },
                .gnux32 => {
                    if (arch == .x86_64) {
                        return "/libx32/ld-linux-x32.so.2";
                    }
                },
                .musl,
                .musleabi,
                .musleabihf,
                => {
                    if (arch == .x86_64) {
                        return "/lib/ld-musl-x86_64.so.1";
                    }
                },
                else => {},
            }
            switch (arch) {
                .i386,
                .sparc,
                .sparcel,
                => return "/lib/ld-linux.so.2",

                .aarch64 => return "/lib/ld-linux-aarch64.so.1",

                .aarch64_be => return "/lib/ld-linux-aarch64_be.so.1",

                .arm,
                .thumb,
                => return switch (getFloatAbi(self)) {
                    .Hard => return "/lib/ld-linux-armhf.so.3",
                    else => return "/lib/ld-linux.so.3",
                },

                .armeb,
                .thumbeb,
                => return switch (getFloatAbi(self)) {
                    .Hard => return "/lib/ld-linux-armhf.so.3",
                    else => return "/lib/ld-linux.so.3",
                },

                .mips,
                .mipsel,
                .mips64,
                .mips64el,
                => return null,

                .powerpc => return "/lib/ld.so.1",
                .powerpc64 => return "/lib64/ld64.so.2",
                .powerpc64le => return "/lib64/ld64.so.2",
                .s390x => return "/lib64/ld64.so.1",
                .sparcv9 => return "/lib64/ld-linux.so.2",
                .x86_64 => return "/lib64/ld-linux-x86-64.so.2",

                .arc,
                .avr,
                .bpfel,
                .bpfeb,
                .hexagon,
                .msp430,
                .r600,
                .amdgcn,
                .riscv32,
                .riscv64,
                .tce,
                .tcele,
                .xcore,
                .nvptx,
                .nvptx64,
                .le32,
                .le64,
                .amdil,
                .amdil64,
                .hsail,
                .hsail64,
                .spir,
                .spir64,
                .kalimba,
                .shave,
                .lanai,
                .wasm32,
                .wasm64,
                .renderscript32,
                .renderscript64,
                .aarch64_32,
                => return null,
            }
        },
        else => return null,
    }
}

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
