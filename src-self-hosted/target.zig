// const builtin = @import("builtin");

pub const FloatAbi = enum {
    Hard,
    Soft,
    SoftFp,
};

// pub const Cross = struct {
//     arch: Target.Arch,
//     os: Target.Os,
//     abi: Target.Abi,
//     object_format: builtin.ObjectFormat,
// };

// pub fn getObjectFormat(self: Target) builtin.ObjectFormat {
//     return switch (self) {
//         .Native => builtin.object_format,
//         .Cross => |t| t.object_format,
//     };
// }

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
                    if (is64bit(self)) {
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

pub fn getDarwinArchString(self: Target) []const u8 {
    const arch = self.getArch();
    switch (arch) {
        .aarch64 => return "arm64",
        .thumb,
        .arm,
        => return "arm",
        .powerpc => return "ppc",
        .powerpc64 => return "ppc64",
        .powerpc64le => return "ppc64le",
        else => return @tagName(arch),
    }
}
