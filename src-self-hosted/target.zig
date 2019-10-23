const std = @import("std");
const builtin = @import("builtin");
const llvm = @import("llvm.zig");
const CInt = @import("c_int.zig").CInt;

// TODO delete this file and use std.Target

pub const FloatAbi = enum {
    Hard,
    Soft,
    SoftFp,
};

pub const Target = union(enum) {
    Native,
    Cross: Cross,

    pub const Cross = struct {
        arch: builtin.Arch,
        os: builtin.Os,
        abi: builtin.Abi,
        object_format: builtin.ObjectFormat,
    };

    pub fn objFileExt(self: Target) []const u8 {
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

    pub fn libFileExt(self: Target, is_static: bool) []const u8 {
        return switch (self.getOs()) {
            builtin.Os.windows => if (is_static) ".lib" else ".dll",
            else => if (is_static) ".a" else ".so",
        };
    }

    pub fn getOs(self: Target) builtin.Os {
        return switch (self) {
            Target.Native => builtin.os,
            @TagType(Target).Cross => |t| t.os,
        };
    }

    pub fn getArch(self: Target) builtin.Arch {
        switch (self) {
            Target.Native => return builtin.arch,
            @TagType(Target).Cross => |t| return t.arch,
        }
    }

    pub fn getAbi(self: Target) builtin.Abi {
        return switch (self) {
            Target.Native => builtin.abi,
            @TagType(Target).Cross => |t| t.abi,
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

    /// TODO expose the arch and subarch separately
    pub fn isArmOrThumb(self: Target) bool {
        return switch (self.getArch()) {
            builtin.Arch.arm,
            builtin.Arch.armeb,
            builtin.Arch.aarch64,
            builtin.Arch.aarch64_be,
            builtin.Arch.thumb,
            builtin.Arch.thumbeb,
            => true,
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
        // LLVM determines the output format based on the abi suffix,
        // defaulting to an object based on the architecture. The default format in
        // LLVM 6 sets the wasm arch output incorrectly to ELF. We need to
        // explicitly set this ourself in order for it to work.
        //
        // This is fixed in LLVM 7 and you will be able to get wasm output by
        // using the target triple `wasm32-unknown-unknown-unknown`.
        const env_name = if (self.isWasm()) "wasm" else @tagName(self.getAbi());

        var out = &std.io.BufferOutStream.init(&result).stream;
        try out.print("{}-unknown-{}-{}", @tagName(self.getArch()), @tagName(self.getOs()), env_name);

        return result;
    }

    pub fn is64bit(self: Target) bool {
        return self.getArchPtrBitWidth() == 64;
    }

    pub fn getArchPtrBitWidth(self: Target) u32 {
        switch (self.getArch()) {
            builtin.Arch.avr,
            builtin.Arch.msp430,
            => return 16,

            builtin.Arch.arc,
            builtin.Arch.arm,
            builtin.Arch.armeb,
            builtin.Arch.hexagon,
            builtin.Arch.le32,
            builtin.Arch.mips,
            builtin.Arch.mipsel,
            builtin.Arch.powerpc,
            builtin.Arch.r600,
            builtin.Arch.riscv32,
            builtin.Arch.sparc,
            builtin.Arch.sparcel,
            builtin.Arch.tce,
            builtin.Arch.tcele,
            builtin.Arch.thumb,
            builtin.Arch.thumbeb,
            builtin.Arch.i386,
            builtin.Arch.xcore,
            builtin.Arch.nvptx,
            builtin.Arch.amdil,
            builtin.Arch.hsail,
            builtin.Arch.spir,
            builtin.Arch.kalimba,
            builtin.Arch.shave,
            builtin.Arch.lanai,
            builtin.Arch.wasm32,
            builtin.Arch.renderscript32,
            => return 32,

            builtin.Arch.aarch64,
            builtin.Arch.aarch64_be,
            builtin.Arch.mips64,
            builtin.Arch.mips64el,
            builtin.Arch.powerpc64,
            builtin.Arch.powerpc64le,
            builtin.Arch.riscv64,
            builtin.Arch.x86_64,
            builtin.Arch.nvptx64,
            builtin.Arch.le64,
            builtin.Arch.amdil64,
            builtin.Arch.hsail64,
            builtin.Arch.spir64,
            builtin.Arch.wasm64,
            builtin.Arch.renderscript64,
            builtin.Arch.amdgcn,
            builtin.Arch.bpfel,
            builtin.Arch.bpfeb,
            builtin.Arch.sparcv9,
            builtin.Arch.s390x,
            => return 64,
        }
    }

    pub fn getFloatAbi(self: Target) FloatAbi {
        return switch (self.getAbi()) {
            builtin.Abi.gnueabihf,
            builtin.Abi.eabihf,
            builtin.Abi.musleabihf,
            => FloatAbi.Hard,
            else => FloatAbi.Soft,
        };
    }

    pub fn getDynamicLinkerPath(self: Target) ?[]const u8 {
        const env = self.getAbi();
        const arch = self.getArch();
        const os = self.getOs();
        switch (os) {
            builtin.Os.freebsd => {
                return "/libexec/ld-elf.so.1";
            },
            builtin.Os.linux => {
                switch (env) {
                    builtin.Abi.android => {
                        if (self.is64bit()) {
                            return "/system/bin/linker64";
                        } else {
                            return "/system/bin/linker";
                        }
                    },
                    builtin.Abi.gnux32 => {
                        if (arch == builtin.Arch.x86_64) {
                            return "/libx32/ld-linux-x32.so.2";
                        }
                    },
                    builtin.Abi.musl,
                    builtin.Abi.musleabi,
                    builtin.Abi.musleabihf,
                    => {
                        if (arch == builtin.Arch.x86_64) {
                            return "/lib/ld-musl-x86_64.so.1";
                        }
                    },
                    else => {},
                }
                switch (arch) {
                    builtin.Arch.i386,
                    builtin.Arch.sparc,
                    builtin.Arch.sparcel,
                    => return "/lib/ld-linux.so.2",

                    builtin.Arch.aarch64 => return "/lib/ld-linux-aarch64.so.1",

                    builtin.Arch.aarch64_be => return "/lib/ld-linux-aarch64_be.so.1",

                    builtin.Arch.arm,
                    builtin.Arch.thumb,
                    => return switch (self.getFloatAbi()) {
                        FloatAbi.Hard => return "/lib/ld-linux-armhf.so.3",
                        else => return "/lib/ld-linux.so.3",
                    },

                    builtin.Arch.armeb,
                    builtin.Arch.thumbeb,
                    => return switch (self.getFloatAbi()) {
                        FloatAbi.Hard => return "/lib/ld-linux-armhf.so.3",
                        else => return "/lib/ld-linux.so.3",
                    },

                    builtin.Arch.mips,
                    builtin.Arch.mipsel,
                    builtin.Arch.mips64,
                    builtin.Arch.mips64el,
                    => return null,

                    builtin.Arch.powerpc => return "/lib/ld.so.1",
                    builtin.Arch.powerpc64 => return "/lib64/ld64.so.2",
                    builtin.Arch.powerpc64le => return "/lib64/ld64.so.2",
                    builtin.Arch.s390x => return "/lib64/ld64.so.1",
                    builtin.Arch.sparcv9 => return "/lib64/ld-linux.so.2",
                    builtin.Arch.x86_64 => return "/lib64/ld-linux-x86-64.so.2",

                    builtin.Arch.arc,
                    builtin.Arch.avr,
                    builtin.Arch.bpfel,
                    builtin.Arch.bpfeb,
                    builtin.Arch.hexagon,
                    builtin.Arch.msp430,
                    builtin.Arch.r600,
                    builtin.Arch.amdgcn,
                    builtin.Arch.riscv32,
                    builtin.Arch.riscv64,
                    builtin.Arch.tce,
                    builtin.Arch.tcele,
                    builtin.Arch.xcore,
                    builtin.Arch.nvptx,
                    builtin.Arch.nvptx64,
                    builtin.Arch.le32,
                    builtin.Arch.le64,
                    builtin.Arch.amdil,
                    builtin.Arch.amdil64,
                    builtin.Arch.hsail,
                    builtin.Arch.hsail64,
                    builtin.Arch.spir,
                    builtin.Arch.spir64,
                    builtin.Arch.kalimba,
                    builtin.Arch.shave,
                    builtin.Arch.lanai,
                    builtin.Arch.wasm32,
                    builtin.Arch.wasm64,
                    builtin.Arch.renderscript32,
                    builtin.Arch.renderscript64,
                    => return null,
                }
            },
            else => return null,
        }
    }

    pub fn llvmTargetFromTriple(triple: std.Buffer) !*llvm.Target {
        var result: *llvm.Target = undefined;
        var err_msg: [*]u8 = undefined;
        if (llvm.GetTargetFromTriple(triple.ptr(), &result, &err_msg) != 0) {
            std.debug.warn("triple: {s} error: {s}\n", triple.ptr(), err_msg);
            return error.UnsupportedTarget;
        }
        return result;
    }

    pub fn cIntTypeSizeInBits(self: Target, id: CInt.Id) u32 {
        const arch = self.getArch();
        switch (self.getOs()) {
            builtin.Os.freestanding => switch (self.getArch()) {
                builtin.Arch.msp430 => switch (id) {
                    CInt.Id.Short,
                    CInt.Id.UShort,
                    CInt.Id.Int,
                    CInt.Id.UInt,
                    => return 16,
                    CInt.Id.Long,
                    CInt.Id.ULong,
                    => return 32,
                    CInt.Id.LongLong,
                    CInt.Id.ULongLong,
                    => return 64,
                },
                else => switch (id) {
                    CInt.Id.Short,
                    CInt.Id.UShort,
                    => return 16,
                    CInt.Id.Int,
                    CInt.Id.UInt,
                    => return 32,
                    CInt.Id.Long,
                    CInt.Id.ULong,
                    => return self.getArchPtrBitWidth(),
                    CInt.Id.LongLong,
                    CInt.Id.ULongLong,
                    => return 64,
                },
            },

            builtin.Os.linux,
            builtin.Os.macosx,
            builtin.Os.freebsd,
            builtin.Os.openbsd,
            builtin.Os.zen,
            => switch (id) {
                CInt.Id.Short,
                CInt.Id.UShort,
                => return 16,
                CInt.Id.Int,
                CInt.Id.UInt,
                => return 32,
                CInt.Id.Long,
                CInt.Id.ULong,
                => return self.getArchPtrBitWidth(),
                CInt.Id.LongLong,
                CInt.Id.ULongLong,
                => return 64,
            },

            builtin.Os.windows, builtin.Os.uefi => switch (id) {
                CInt.Id.Short,
                CInt.Id.UShort,
                => return 16,
                CInt.Id.Int,
                CInt.Id.UInt,
                => return 32,
                CInt.Id.Long,
                CInt.Id.ULong,
                CInt.Id.LongLong,
                CInt.Id.ULongLong,
                => return 64,
            },

            builtin.Os.ananas,
            builtin.Os.cloudabi,
            builtin.Os.dragonfly,
            builtin.Os.fuchsia,
            builtin.Os.ios,
            builtin.Os.kfreebsd,
            builtin.Os.lv2,
            builtin.Os.netbsd,
            builtin.Os.solaris,
            builtin.Os.haiku,
            builtin.Os.minix,
            builtin.Os.rtems,
            builtin.Os.nacl,
            builtin.Os.cnk,
            builtin.Os.aix,
            builtin.Os.cuda,
            builtin.Os.nvcl,
            builtin.Os.amdhsa,
            builtin.Os.ps4,
            builtin.Os.elfiamcu,
            builtin.Os.tvos,
            builtin.Os.watchos,
            builtin.Os.mesa3d,
            builtin.Os.contiki,
            builtin.Os.amdpal,
            builtin.Os.hermit,
            builtin.Os.hurd,
            builtin.Os.wasi,
            => @panic("TODO specify the C integer type sizes for this OS"),
        }
    }

    pub fn getDarwinArchString(self: Target) []const u8 {
        const arch = self.getArch();
        switch (arch) {
            builtin.Arch.aarch64 => return "arm64",
            builtin.Arch.thumb,
            builtin.Arch.arm,
            => return "arm",
            builtin.Arch.powerpc => return "ppc",
            builtin.Arch.powerpc64 => return "ppc64",
            builtin.Arch.powerpc64le => return "ppc64le",
            else => return @tagName(arch),
        }
    }
};
