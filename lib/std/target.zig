const std = @import("std.zig");
const mem = std.mem;
const builtin = std.builtin;

/// TODO Nearly all the functions in this namespace would be
/// better off if https://github.com/ziglang/zig/issues/425
/// was solved.
pub const Target = union(enum) {
    Native: void,
    Cross: Cross,

    pub const Os = enum {
        freestanding,
        ananas,
        cloudabi,
        dragonfly,
        freebsd,
        fuchsia,
        ios,
        kfreebsd,
        linux,
        lv2,
        macosx,
        netbsd,
        openbsd,
        solaris,
        windows,
        haiku,
        minix,
        rtems,
        nacl,
        cnk,
        aix,
        cuda,
        nvcl,
        amdhsa,
        ps4,
        elfiamcu,
        tvos,
        watchos,
        mesa3d,
        contiki,
        amdpal,
        hermit,
        hurd,
        wasi,
        emscripten,
        zen,
        uefi,
    };

    pub const Arch = union(enum) {
        arm: Arm32,
        armeb: Arm32,
        aarch64: Arm64,
        aarch64_be: Arm64,
        aarch64_32: Arm64,
        arc,
        avr,
        bpfel,
        bpfeb,
        hexagon,
        mips,
        mipsel,
        mips64,
        mips64el,
        msp430,
        powerpc,
        powerpc64,
        powerpc64le,
        r600,
        amdgcn,
        riscv32,
        riscv64,
        sparc,
        sparcv9,
        sparcel,
        s390x,
        tce,
        tcele,
        thumb: Arm32,
        thumbeb: Arm32,
        i386,
        x86_64,
        xcore,
        nvptx,
        nvptx64,
        le32,
        le64,
        amdil,
        amdil64,
        hsail,
        hsail64,
        spir,
        spir64,
        kalimba: Kalimba,
        shave,
        lanai,
        wasm32,
        wasm64,
        renderscript32,
        renderscript64,

        pub const Arm32 = enum {
            v8_5a,
            v8_4a,
            v8_3a,
            v8_2a,
            v8_1a,
            v8,
            v8r,
            v8m_baseline,
            v8m_mainline,
            v8_1m_mainline,
            v7,
            v7em,
            v7m,
            v7s,
            v7k,
            v7ve,
            v6,
            v6m,
            v6k,
            v6t2,
            v5,
            v5te,
            v4t,
        };
        pub const Arm64 = enum {
            v8_5a,
            v8_4a,
            v8_3a,
            v8_2a,
            v8_1a,
            v8,
            v8r,
            v8m_baseline,
            v8m_mainline,
        };
        pub const Kalimba = enum {
            v5,
            v4,
            v3,
        };
        pub const Mips = enum {
            r6,
        };
    };

    pub const Abi = enum {
        none,
        gnu,
        gnuabin32,
        gnuabi64,
        gnueabi,
        gnueabihf,
        gnux32,
        code16,
        eabi,
        eabihf,
        elfv1,
        elfv2,
        android,
        musl,
        musleabi,
        musleabihf,
        msvc,
        itanium,
        cygnus,
        coreclr,
        simulator,
        macabi,
    };

    pub const ObjectFormat = enum {
        unknown,
        coff,
        elf,
        macho,
        wasm,
    };

    pub const SubSystem = enum {
        Console,
        Windows,
        Posix,
        Native,
        EfiApplication,
        EfiBootServiceDriver,
        EfiRom,
        EfiRuntimeDriver,
    };

    pub const Cross = struct {
        arch: Arch,
        os: Os,
        abi: Abi,
    };

    pub const current = Target{
        .Cross = Cross{
            .arch = builtin.arch,
            .os = builtin.os,
            .abi = builtin.abi,
        },
    };

    pub fn zigTriple(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{}{}-{}-{}",
            @tagName(self.getArch()),
            Target.archSubArchName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        );
    }

    pub fn allocDescription(self: Target, allocator: *mem.Allocator) ![]u8 {
        // TODO is there anything else worthy of the description that is not
        // already captured in the triple?
        return self.zigTriple(allocator);
    }

    pub fn zigTripleNoSubArch(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{}-{}-{}",
            @tagName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        );
    }

    pub fn linuxTriple(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{}-{}-{}",
            @tagName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        );
    }

    pub fn parse(text: []const u8) !Target {
        var it = mem.separate(text, "-");
        const arch_name = it.next() orelse return error.MissingArchitecture;
        const os_name = it.next() orelse return error.MissingOperatingSystem;
        const abi_name = it.next();

        var cross = Cross{
            .arch = try parseArchSub(arch_name),
            .os = try parseOs(os_name),
            .abi = undefined,
        };
        cross.abi = if (abi_name) |n| try parseAbi(n) else defaultAbi(cross.arch, cross.os);
        return Target{ .Cross = cross };
    }

    pub fn defaultAbi(arch: Arch, target_os: Os) Abi {
        switch (arch) {
            .wasm32, .wasm64 => return .musl,
            else => {},
        }
        switch (target_os) {
            .freestanding,
            .ananas,
            .cloudabi,
            .dragonfly,
            .lv2,
            .solaris,
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .cnk,
            .aix,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .elfiamcu,
            .mesa3d,
            .contiki,
            .amdpal,
            .zen,
            .hermit,
            => return .eabi,
            .openbsd,
            .macosx,
            .freebsd,
            .ios,
            .tvos,
            .watchos,
            .fuchsia,
            .kfreebsd,
            .netbsd,
            .hurd,
            => return .gnu,
            .windows,
            .uefi,
            => return .msvc,
            .linux,
            .wasi,
            .emscripten,
            => return .musl,
        }
    }

    pub const ParseArchSubError = error{
        UnknownArchitecture,
        UnknownSubArchitecture,
    };

    pub fn parseArchSub(text: []const u8) ParseArchSubError!Arch {
        const info = @typeInfo(Arch);
        inline for (info.Union.fields) |field| {
            if (mem.eql(u8, text, field.name)) {
                if (field.field_type == void) {
                    return (Arch)(@field(Arch, field.name));
                } else {
                    const sub_info = @typeInfo(field.field_type);
                    inline for (sub_info.Enum.fields) |sub_field| {
                        const combined = field.name ++ sub_field.name;
                        if (mem.eql(u8, text, combined)) {
                            return @unionInit(Arch, field.name, @field(field.field_type, sub_field.name));
                        }
                    }
                    return error.UnknownSubArchitecture;
                }
            }
        }
        return error.UnknownArchitecture;
    }

    pub fn parseOs(text: []const u8) !Os {
        const info = @typeInfo(Os);
        inline for (info.Enum.fields) |field| {
            if (mem.eql(u8, text, field.name)) {
                return @field(Os, field.name);
            }
        }
        return error.UnknownOperatingSystem;
    }

    pub fn parseAbi(text: []const u8) !Abi {
        const info = @typeInfo(Abi);
        inline for (info.Enum.fields) |field| {
            if (mem.eql(u8, text, field.name)) {
                return @field(Abi, field.name);
            }
        }
        return error.UnknownApplicationBinaryInterface;
    }

    fn archSubArchName(arch: Arch) []const u8 {
        return switch (arch) {
            .arm => |sub| @tagName(sub),
            .armeb => |sub| @tagName(sub),
            .thumb => |sub| @tagName(sub),
            .thumbeb => |sub| @tagName(sub),
            .aarch64 => |sub| @tagName(sub),
            .aarch64_be => |sub| @tagName(sub),
            .kalimba => |sub| @tagName(sub),
            else => "",
        };
    }

    pub fn subArchName(self: Target) []const u8 {
        switch (self) {
            .Native => return archSubArchName(builtin.arch),
            .Cross => |cross| return archSubArchName(cross.arch),
        }
    }

    pub fn oFileExt(self: Target) []const u8 {
        return switch (self.getAbi()) {
            .msvc => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: Target) []const u8 {
        if (self.isWindows()) {
            return ".exe";
        } else if (self.isUefi()) {
            return ".efi";
        } else if (self.isWasm()) {
            return ".wasm";
        } else {
            return "";
        }
    }

    pub fn staticLibSuffix(self: Target) []const u8 {
        if (self.isWasm()) {
            return ".wasm";
        }
        switch (self.getAbi()) {
            .msvc => return ".lib",
            else => return ".a",
        }
    }

    pub fn dynamicLibSuffix(self: Target) []const u8 {
        if (self.isDarwin()) {
            return ".dylib";
        }
        switch (self.getOs()) {
            .windows => return ".dll",
            else => return ".so",
        }
    }

    pub fn libPrefix(self: Target) []const u8 {
        if (self.isWasm()) {
            return "";
        }
        switch (self.getAbi()) {
            .msvc => return "",
            else => return "lib",
        }
    }

    pub fn getOs(self: Target) Os {
        return switch (self) {
            .Native => builtin.os,
            .Cross => |t| t.os,
        };
    }

    pub fn getArch(self: Target) Arch {
        switch (self) {
            .Native => return builtin.arch,
            .Cross => |t| return t.arch,
        }
    }

    pub fn getAbi(self: Target) Abi {
        switch (self) {
            .Native => return builtin.abi,
            .Cross => |t| return t.abi,
        }
    }

    pub fn isMinGW(self: Target) bool {
        return self.isWindows() and self.isGnu();
    }

    pub fn isGnu(self: Target) bool {
        return switch (self.getAbi()) {
            .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => true,
            else => false,
        };
    }

    pub fn isDarwin(self: Target) bool {
        return switch (self.getOs()) {
            .ios, .macosx, .watchos, .tvos => true,
            else => false,
        };
    }

    pub fn isWindows(self: Target) bool {
        return switch (self.getOs()) {
            .windows => true,
            else => false,
        };
    }

    pub fn isLinux(self: Target) bool {
        return switch (self.getOs()) {
            .linux => true,
            else => false,
        };
    }

    pub fn isUefi(self: Target) bool {
        return switch (self.getOs()) {
            .uefi => true,
            else => false,
        };
    }

    pub fn isWasm(self: Target) bool {
        return switch (self.getArch()) {
            .wasm32, .wasm64 => true,
            else => false,
        };
    }

    pub fn isFreeBSD(self: Target) bool {
        return switch (self.getOs()) {
            .freebsd => true,
            else => false,
        };
    }

    pub fn isNetBSD(self: Target) bool {
        return switch (self.getOs()) {
            .netbsd => true,
            else => false,
        };
    }

    pub fn wantSharedLibSymLinks(self: Target) bool {
        return !self.isWindows();
    }

    pub fn osRequiresLibC(self: Target) bool {
        return self.isDarwin() or self.isFreeBSD() or self.isNetBSD();
    }

    pub fn getArchPtrBitWidth(self: Target) u32 {
        switch (self.getArch()) {
            .avr,
            .msp430,
            => return 16,

            .arc,
            .arm,
            .armeb,
            .hexagon,
            .le32,
            .mips,
            .mipsel,
            .powerpc,
            .r600,
            .riscv32,
            .sparc,
            .sparcel,
            .tce,
            .tcele,
            .thumb,
            .thumbeb,
            .i386,
            .xcore,
            .nvptx,
            .amdil,
            .hsail,
            .spir,
            .kalimba,
            .shave,
            .lanai,
            .wasm32,
            .renderscript32,
            .aarch64_32,
            => return 32,

            .aarch64,
            .aarch64_be,
            .mips64,
            .mips64el,
            .powerpc64,
            .powerpc64le,
            .riscv64,
            .x86_64,
            .nvptx64,
            .le64,
            .amdil64,
            .hsail64,
            .spir64,
            .wasm64,
            .renderscript64,
            .amdgcn,
            .bpfel,
            .bpfeb,
            .sparcv9,
            .s390x,
            => return 64,
        }
    }

    pub const Executor = union(enum) {
        native,
        qemu: []const u8,
        wine: []const u8,
        unavailable,
    };

    pub fn getExternalExecutor(self: Target) Executor {
        if (@TagType(Target)(self) == .Native) return .native;

        // If the target OS matches the host OS, we can use QEMU to emulate a foreign architecture.
        if (self.getOs() == builtin.os) {
            return switch (self.getArch()) {
                .aarch64 => Executor{ .qemu = "qemu-aarch64" },
                .aarch64_be => Executor{ .qemu = "qemu-aarch64_be" },
                .arm => Executor{ .qemu = "qemu-arm" },
                .armeb => Executor{ .qemu = "qemu-armeb" },
                .i386 => Executor{ .qemu = "qemu-i386" },
                .mips => Executor{ .qemu = "qemu-mips" },
                .mipsel => Executor{ .qemu = "qemu-mipsel" },
                .mips64 => Executor{ .qemu = "qemu-mips64" },
                .mips64el => Executor{ .qemu = "qemu-mips64el" },
                .powerpc => Executor{ .qemu = "qemu-ppc" },
                .powerpc64 => Executor{ .qemu = "qemu-ppc64" },
                .powerpc64le => Executor{ .qemu = "qemu-ppc64le" },
                .riscv32 => Executor{ .qemu = "qemu-riscv32" },
                .riscv64 => Executor{ .qemu = "qemu-riscv64" },
                .s390x => Executor{ .qemu = "qemu-s390x" },
                .sparc => Executor{ .qemu = "qemu-sparc" },
                .x86_64 => Executor{ .qemu = "qemu-x86_64" },
                else => return .unavailable,
            };
        }

        if (self.isWindows()) {
            switch (self.getArchPtrBitWidth()) {
                32 => return Executor{ .wine = "wine" },
                64 => return Executor{ .wine = "wine64" },
                else => return .unavailable,
            }
        }

        return .unavailable;
    }
};
