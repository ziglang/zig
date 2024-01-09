const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);
const math = std.math;
const DW = std.dwarf;

const Builder = @import("llvm/Builder.zig");
const llvm = if (build_options.have_llvm)
    @import("llvm/bindings.zig")
else
    @compileError("LLVM unavailable");
const link = @import("../link.zig");
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const Module = @import("../Module.zig");
const Zcu = Module;
const InternPool = @import("../InternPool.zig");
const Package = @import("../Package.zig");
const TypedValue = @import("../TypedValue.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const LazySrcLoc = Module.LazySrcLoc;
const x86_64_abi = @import("../arch/x86_64/abi.zig");
const wasm_c_abi = @import("../arch/wasm/abi.zig");
const aarch64_c_abi = @import("../arch/aarch64/abi.zig");
const arm_c_abi = @import("../arch/arm/abi.zig");
const riscv_c_abi = @import("../arch/riscv64/abi.zig");

const target_util = @import("../target.zig");
const libcFloatPrefix = target_util.libcFloatPrefix;
const libcFloatSuffix = target_util.libcFloatSuffix;
const compilerRtFloatAbbrev = target_util.compilerRtFloatAbbrev;
const compilerRtIntAbbrev = target_util.compilerRtIntAbbrev;

const Error = error{ OutOfMemory, CodegenFail };

pub fn targetTriple(allocator: Allocator, target: std.Target) ![]const u8 {
    var llvm_triple = std.ArrayList(u8).init(allocator);
    defer llvm_triple.deinit();

    const llvm_arch = switch (target.cpu.arch) {
        .arm => "arm",
        .armeb => "armeb",
        .aarch64 => "aarch64",
        .aarch64_be => "aarch64_be",
        .aarch64_32 => "aarch64_32",
        .arc => "arc",
        .avr => "avr",
        .bpfel => "bpfel",
        .bpfeb => "bpfeb",
        .csky => "csky",
        .dxil => "dxil",
        .hexagon => "hexagon",
        .loongarch32 => "loongarch32",
        .loongarch64 => "loongarch64",
        .m68k => "m68k",
        .mips => "mips",
        .mipsel => "mipsel",
        .mips64 => "mips64",
        .mips64el => "mips64el",
        .msp430 => "msp430",
        .powerpc => "powerpc",
        .powerpcle => "powerpcle",
        .powerpc64 => "powerpc64",
        .powerpc64le => "powerpc64le",
        .r600 => "r600",
        .amdgcn => "amdgcn",
        .riscv32 => "riscv32",
        .riscv64 => "riscv64",
        .sparc => "sparc",
        .sparc64 => "sparc64",
        .sparcel => "sparcel",
        .s390x => "s390x",
        .tce => "tce",
        .tcele => "tcele",
        .thumb => "thumb",
        .thumbeb => "thumbeb",
        .x86 => "i386",
        .x86_64 => "x86_64",
        .xcore => "xcore",
        .xtensa => "xtensa",
        .nvptx => "nvptx",
        .nvptx64 => "nvptx64",
        .le32 => "le32",
        .le64 => "le64",
        .amdil => "amdil",
        .amdil64 => "amdil64",
        .hsail => "hsail",
        .hsail64 => "hsail64",
        .spir => "spir",
        .spir64 => "spir64",
        .spirv32 => "spirv32",
        .spirv64 => "spirv64",
        .kalimba => "kalimba",
        .shave => "shave",
        .lanai => "lanai",
        .wasm32 => "wasm32",
        .wasm64 => "wasm64",
        .renderscript32 => "renderscript32",
        .renderscript64 => "renderscript64",
        .ve => "ve",
        .spu_2 => return error.@"LLVM backend does not support SPU Mark II",
    };
    try llvm_triple.appendSlice(llvm_arch);
    try llvm_triple.appendSlice("-unknown-");

    const llvm_os = switch (target.os.tag) {
        .freestanding => "unknown",
        .ananas => "ananas",
        .cloudabi => "cloudabi",
        .dragonfly => "dragonfly",
        .freebsd => "freebsd",
        .fuchsia => "fuchsia",
        .kfreebsd => "kfreebsd",
        .linux => "linux",
        .lv2 => "lv2",
        .netbsd => "netbsd",
        .openbsd => "openbsd",
        .solaris, .illumos => "solaris",
        .windows => "windows",
        .zos => "zos",
        .haiku => "haiku",
        .minix => "minix",
        .rtems => "rtems",
        .nacl => "nacl",
        .aix => "aix",
        .cuda => "cuda",
        .nvcl => "nvcl",
        .amdhsa => "amdhsa",
        .ps4 => "ps4",
        .ps5 => "ps5",
        .elfiamcu => "elfiamcu",
        .mesa3d => "mesa3d",
        .contiki => "contiki",
        .amdpal => "amdpal",
        .hermit => "hermit",
        .hurd => "hurd",
        .wasi => "wasi",
        .emscripten => "emscripten",
        .uefi => "windows",
        .macos => "macosx",
        .ios => "ios",
        .tvos => "tvos",
        .watchos => "watchos",
        .driverkit => "driverkit",
        .shadermodel => "shadermodel",
        .liteos => "liteos",
        .opencl,
        .glsl450,
        .vulkan,
        .plan9,
        .other,
        => "unknown",
    };
    try llvm_triple.appendSlice(llvm_os);

    if (target.os.tag.isDarwin()) {
        const min_version = target.os.version_range.semver.min;
        try llvm_triple.writer().print("{d}.{d}.{d}", .{
            min_version.major,
            min_version.minor,
            min_version.patch,
        });
    }
    try llvm_triple.append('-');

    const llvm_abi = switch (target.abi) {
        .none => "unknown",
        .gnu => "gnu",
        .gnuabin32 => "gnuabin32",
        .gnuabi64 => "gnuabi64",
        .gnueabi => "gnueabi",
        .gnueabihf => "gnueabihf",
        .gnuf32 => "gnuf32",
        .gnuf64 => "gnuf64",
        .gnusf => "gnusf",
        .gnux32 => "gnux32",
        .gnuilp32 => "gnuilp32",
        .code16 => "code16",
        .eabi => "eabi",
        .eabihf => "eabihf",
        .android => "android",
        .musl => "musl",
        .musleabi => "musleabi",
        .musleabihf => "musleabihf",
        .muslx32 => "muslx32",
        .msvc => "msvc",
        .itanium => "itanium",
        .cygnus => "cygnus",
        .coreclr => "coreclr",
        .simulator => "simulator",
        .macabi => "macabi",
        .pixel => "pixel",
        .vertex => "vertex",
        .geometry => "geometry",
        .hull => "hull",
        .domain => "domain",
        .compute => "compute",
        .library => "library",
        .raygeneration => "raygeneration",
        .intersection => "intersection",
        .anyhit => "anyhit",
        .closesthit => "closesthit",
        .miss => "miss",
        .callable => "callable",
        .mesh => "mesh",
        .amplification => "amplification",
    };
    try llvm_triple.appendSlice(llvm_abi);

    return llvm_triple.toOwnedSlice();
}

pub fn targetOs(os_tag: std.Target.Os.Tag) llvm.OSType {
    return switch (os_tag) {
        .freestanding, .other, .opencl, .glsl450, .vulkan, .plan9 => .UnknownOS,
        .windows, .uefi => .Win32,
        .ananas => .Ananas,
        .cloudabi => .CloudABI,
        .dragonfly => .DragonFly,
        .freebsd => .FreeBSD,
        .fuchsia => .Fuchsia,
        .ios => .IOS,
        .kfreebsd => .KFreeBSD,
        .linux => .Linux,
        .lv2 => .Lv2,
        .macos => .MacOSX,
        .netbsd => .NetBSD,
        .openbsd => .OpenBSD,
        .solaris, .illumos => .Solaris,
        .zos => .ZOS,
        .haiku => .Haiku,
        .minix => .Minix,
        .rtems => .RTEMS,
        .nacl => .NaCl,
        .aix => .AIX,
        .cuda => .CUDA,
        .nvcl => .NVCL,
        .amdhsa => .AMDHSA,
        .ps4 => .PS4,
        .ps5 => .PS5,
        .elfiamcu => .ELFIAMCU,
        .tvos => .TvOS,
        .watchos => .WatchOS,
        .mesa3d => .Mesa3D,
        .contiki => .Contiki,
        .amdpal => .AMDPAL,
        .hermit => .HermitCore,
        .hurd => .Hurd,
        .wasi => .WASI,
        .emscripten => .Emscripten,
        .driverkit => .DriverKit,
        .shadermodel => .ShaderModel,
        .liteos => .LiteOS,
    };
}

pub fn targetArch(arch_tag: std.Target.Cpu.Arch) llvm.ArchType {
    return switch (arch_tag) {
        .arm => .arm,
        .armeb => .armeb,
        .aarch64 => .aarch64,
        .aarch64_be => .aarch64_be,
        .aarch64_32 => .aarch64_32,
        .arc => .arc,
        .avr => .avr,
        .bpfel => .bpfel,
        .bpfeb => .bpfeb,
        .csky => .csky,
        .dxil => .dxil,
        .hexagon => .hexagon,
        .loongarch32 => .loongarch32,
        .loongarch64 => .loongarch64,
        .m68k => .m68k,
        .mips => .mips,
        .mipsel => .mipsel,
        .mips64 => .mips64,
        .mips64el => .mips64el,
        .msp430 => .msp430,
        .powerpc => .ppc,
        .powerpcle => .ppcle,
        .powerpc64 => .ppc64,
        .powerpc64le => .ppc64le,
        .r600 => .r600,
        .amdgcn => .amdgcn,
        .riscv32 => .riscv32,
        .riscv64 => .riscv64,
        .sparc => .sparc,
        .sparc64 => .sparcv9, // In LLVM, sparc64 == sparcv9.
        .sparcel => .sparcel,
        .s390x => .systemz,
        .tce => .tce,
        .tcele => .tcele,
        .thumb => .thumb,
        .thumbeb => .thumbeb,
        .x86 => .x86,
        .x86_64 => .x86_64,
        .xcore => .xcore,
        .xtensa => .xtensa,
        .nvptx => .nvptx,
        .nvptx64 => .nvptx64,
        .le32 => .le32,
        .le64 => .le64,
        .amdil => .amdil,
        .amdil64 => .amdil64,
        .hsail => .hsail,
        .hsail64 => .hsail64,
        .spir => .spir,
        .spir64 => .spir64,
        .kalimba => .kalimba,
        .shave => .shave,
        .lanai => .lanai,
        .wasm32 => .wasm32,
        .wasm64 => .wasm64,
        .renderscript32 => .renderscript32,
        .renderscript64 => .renderscript64,
        .ve => .ve,
        .spu_2, .spirv32, .spirv64 => .UnknownArch,
    };
}

pub fn supportsTailCall(target: std.Target) bool {
    switch (target.cpu.arch) {
        .wasm32, .wasm64 => return std.Target.wasm.featureSetHas(target.cpu.features, .tail_call),
        // Although these ISAs support tail calls, LLVM does not support tail calls on them.
        .mips, .mipsel, .mips64, .mips64el => return false,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => return false,
        else => return true,
    }
}

const DataLayoutBuilder = struct {
    target: std.Target,

    pub fn format(
        self: DataLayoutBuilder,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        try writer.writeByte(switch (self.target.cpu.arch.endian()) {
            .little => 'e',
            .big => 'E',
        });
        switch (self.target.cpu.arch) {
            .amdgcn,
            .nvptx,
            .nvptx64,
            => {},
            .avr => try writer.writeAll("-P1"),
            else => try writer.print("-m:{c}", .{@as(u8, switch (self.target.cpu.arch) {
                .mips, .mipsel => 'm', // Mips mangling: Private symbols get a $ prefix.
                else => switch (self.target.ofmt) {
                    .elf => 'e', // ELF mangling: Private symbols get a `.L` prefix.
                    //.goff => 'l', // GOFF mangling: Private symbols get a `@` prefix.
                    .macho => 'o', // Mach-O mangling: Private symbols get `L` prefix.
                    // Other symbols get a `_` prefix.
                    .coff => switch (self.target.os.tag) {
                        .uefi, .windows => switch (self.target.cpu.arch) {
                            .x86 => 'x', // Windows x86 COFF mangling: Private symbols get the usual
                            // prefix. Regular C symbols get a `_` prefix. Functions with `__stdcall`,
                            //`__fastcall`, and `__vectorcall` have custom mangling that appends `@N`
                            // where N is the number of bytes used to pass parameters. C++ symbols
                            // starting with `?` are not mangled in any way.
                            else => 'w', // Windows COFF mangling: Similar to x, except that normal C
                            // symbols do not receive a `_` prefix.
                        },
                        else => 'e',
                    },
                    //.xcoff => 'a', // XCOFF mangling: Private symbols get a `L..` prefix.
                    else => 'e',
                },
            })}),
        }
        const stack_abi = self.target.stackAlignment() * 8;
        if (self.target.cpu.arch == .csky) try writer.print("-S{d}", .{stack_abi});
        var any_non_integral = false;
        const ptr_bit_width = self.target.ptrBitWidth();
        var default_info = struct { size: u16, abi: u16, pref: u16, idx: u16 }{
            .size = 64,
            .abi = 64,
            .pref = 64,
            .idx = 64,
        };
        const addr_space_info = llvmAddrSpaceInfo(self.target);
        for (addr_space_info, 0..) |info, i| {
            assert((info.llvm == .default) == (i == 0));
            if (info.non_integral) {
                assert(info.llvm != .default);
                any_non_integral = true;
            }
            const size = info.size orelse ptr_bit_width;
            const abi = info.abi orelse ptr_bit_width;
            const pref = info.pref orelse abi;
            const idx = info.idx orelse size;
            const matches_default =
                size == default_info.size and
                abi == default_info.abi and
                pref == default_info.pref and
                idx == default_info.idx;
            if (info.llvm == .default) default_info = .{
                .size = size,
                .abi = abi,
                .pref = pref,
                .idx = idx,
            };
            if (self.target.cpu.arch == .aarch64_32) continue;
            if (!info.force_in_data_layout and matches_default and
                self.target.cpu.arch != .riscv64 and !(self.target.cpu.arch == .aarch64 and
                (self.target.os.tag == .uefi or self.target.os.tag == .windows)) and
                self.target.cpu.arch != .bpfeb and self.target.cpu.arch != .bpfel) continue;
            try writer.writeAll("-p");
            if (info.llvm != .default) try writer.print("{d}", .{@intFromEnum(info.llvm)});
            try writer.print(":{d}:{d}", .{ size, abi });
            if (pref != abi or idx != size or self.target.cpu.arch == .hexagon) {
                try writer.print(":{d}", .{pref});
                if (idx != size) try writer.print(":{d}", .{idx});
            }
        }
        if (self.target.cpu.arch.isArmOrThumb()) try writer.writeAll("-Fi8") // for thumb interwork
        else if (self.target.cpu.arch == .powerpc64 and
            self.target.os.tag != .freebsd and self.target.abi != .musl)
            try writer.writeAll("-Fi64")
        else if (self.target.cpu.arch.isPPC() or self.target.cpu.arch.isPPC64())
            try writer.writeAll("-Fn32");
        if (self.target.cpu.arch != .hexagon) {
            if (self.target.cpu.arch == .arc or self.target.cpu.arch == .s390x)
                try self.typeAlignment(.integer, 1, 8, 8, false, writer);
            try self.typeAlignment(.integer, 8, 8, 8, false, writer);
            try self.typeAlignment(.integer, 16, 16, 16, false, writer);
            try self.typeAlignment(.integer, 32, 32, 32, false, writer);
            if (self.target.cpu.arch == .arc)
                try self.typeAlignment(.float, 32, 32, 32, false, writer);
            try self.typeAlignment(.integer, 64, 32, 64, false, writer);
            try self.typeAlignment(.integer, 128, 32, 64, false, writer);
            if (backendSupportsF16(self.target))
                try self.typeAlignment(.float, 16, 16, 16, false, writer);
            if (self.target.cpu.arch != .arc)
                try self.typeAlignment(.float, 32, 32, 32, false, writer);
            try self.typeAlignment(.float, 64, 64, 64, false, writer);
            if (self.target.cpu.arch.isX86()) try self.typeAlignment(.float, 80, 0, 0, false, writer);
            try self.typeAlignment(.float, 128, 128, 128, false, writer);
        }
        switch (self.target.cpu.arch) {
            .amdgcn => {
                try self.typeAlignment(.vector, 16, 16, 16, false, writer);
                try self.typeAlignment(.vector, 24, 32, 32, false, writer);
                try self.typeAlignment(.vector, 32, 32, 32, false, writer);
                try self.typeAlignment(.vector, 48, 64, 64, false, writer);
                try self.typeAlignment(.vector, 96, 128, 128, false, writer);
                try self.typeAlignment(.vector, 192, 256, 256, false, writer);
                try self.typeAlignment(.vector, 256, 256, 256, false, writer);
                try self.typeAlignment(.vector, 512, 512, 512, false, writer);
                try self.typeAlignment(.vector, 1024, 1024, 1024, false, writer);
                try self.typeAlignment(.vector, 2048, 2048, 2048, false, writer);
            },
            .ve => {},
            else => {
                try self.typeAlignment(.vector, 16, 32, 32, false, writer);
                try self.typeAlignment(.vector, 32, 32, 32, false, writer);
                try self.typeAlignment(.vector, 64, 64, 64, false, writer);
                try self.typeAlignment(.vector, 128, 128, 128, true, writer);
            },
        }
        const swap_agg_nat = switch (self.target.cpu.arch) {
            .x86, .x86_64 => switch (self.target.os.tag) {
                .uefi, .windows => true,
                else => false,
            },
            .avr, .m68k => true,
            else => false,
        };
        if (!swap_agg_nat) try self.typeAlignment(.aggregate, 0, 0, 64, false, writer);
        if (self.target.cpu.arch == .csky) try writer.writeAll("-Fi32");
        for (@as([]const u24, switch (self.target.cpu.arch) {
            .avr => &.{8},
            .msp430 => &.{ 8, 16 },
            .arc,
            .arm,
            .armeb,
            .csky,
            .mips,
            .mipsel,
            .powerpc,
            .powerpcle,
            .riscv32,
            .sparc,
            .sparcel,
            .thumb,
            .thumbeb,
            .xtensa,
            => &.{32},
            .aarch64,
            .aarch64_be,
            .aarch64_32,
            .amdgcn,
            .bpfeb,
            .bpfel,
            .mips64,
            .mips64el,
            .powerpc64,
            .powerpc64le,
            .riscv64,
            .s390x,
            .sparc64,
            .ve,
            .wasm32,
            .wasm64,
            => &.{ 32, 64 },
            .hexagon => &.{ 16, 32 },
            .m68k,
            .x86,
            => &.{ 8, 16, 32 },
            .nvptx,
            .nvptx64,
            => &.{ 16, 32, 64 },
            .x86_64 => &.{ 8, 16, 32, 64 },
            else => &.{},
        }), 0..) |natural, index| switch (index) {
            0 => try writer.print("-n{d}", .{natural}),
            else => try writer.print(":{d}", .{natural}),
        };
        if (swap_agg_nat) try self.typeAlignment(.aggregate, 0, 0, 64, false, writer);
        if (self.target.cpu.arch == .hexagon) {
            try self.typeAlignment(.integer, 64, 64, 64, true, writer);
            try self.typeAlignment(.integer, 32, 32, 32, true, writer);
            try self.typeAlignment(.integer, 16, 16, 16, true, writer);
            try self.typeAlignment(.integer, 1, 8, 8, true, writer);
            try self.typeAlignment(.float, 32, 32, 32, true, writer);
            try self.typeAlignment(.float, 64, 64, 64, true, writer);
        }
        if (stack_abi != ptr_bit_width or self.target.cpu.arch == .msp430 or
            self.target.os.tag == .uefi or self.target.os.tag == .windows)
            try writer.print("-S{d}", .{stack_abi});
        switch (self.target.cpu.arch) {
            .hexagon, .ve => {
                try self.typeAlignment(.vector, 32, 128, 128, true, writer);
                try self.typeAlignment(.vector, 64, 128, 128, true, writer);
                try self.typeAlignment(.vector, 128, 128, 128, true, writer);
            },
            else => {},
        }
        if (self.target.cpu.arch != .amdgcn) {
            try self.typeAlignment(.vector, 256, 128, 128, true, writer);
            try self.typeAlignment(.vector, 512, 128, 128, true, writer);
            try self.typeAlignment(.vector, 1024, 128, 128, true, writer);
            try self.typeAlignment(.vector, 2048, 128, 128, true, writer);
            try self.typeAlignment(.vector, 4096, 128, 128, true, writer);
            try self.typeAlignment(.vector, 8192, 128, 128, true, writer);
            try self.typeAlignment(.vector, 16384, 128, 128, true, writer);
        }
        const alloca_addr_space = llvmAllocaAddressSpace(self.target);
        if (alloca_addr_space != .default) try writer.print("-A{d}", .{@intFromEnum(alloca_addr_space)});
        const global_addr_space = llvmDefaultGlobalAddressSpace(self.target);
        if (global_addr_space != .default) try writer.print("-G{d}", .{@intFromEnum(global_addr_space)});
        if (any_non_integral) {
            try writer.writeAll("-ni");
            for (addr_space_info) |info| if (info.non_integral)
                try writer.print(":{d}", .{@intFromEnum(info.llvm)});
        }
    }

    fn typeAlignment(
        self: DataLayoutBuilder,
        kind: enum { integer, vector, float, aggregate },
        size: u24,
        default_abi: u24,
        default_pref: u24,
        default_force_pref: bool,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        var abi = default_abi;
        var pref = default_pref;
        var force_abi = false;
        var force_pref = default_force_pref;
        if (kind == .float and size == 80) {
            abi = 128;
            pref = 128;
        }
        for (@as([]const std.Target.CType, switch (kind) {
            .integer => &.{ .char, .short, .int, .long, .longlong },
            .float => &.{ .float, .double, .longdouble },
            .vector, .aggregate => &.{},
        })) |cty| {
            if (self.target.c_type_bit_size(cty) != size) continue;
            abi = self.target.c_type_alignment(cty) * 8;
            pref = self.target.c_type_preferred_alignment(cty) * 8;
            break;
        }
        switch (kind) {
            .integer => {
                if (self.target.ptrBitWidth() <= 16 and size >= 128) return;
                abi = @min(abi, self.target.maxIntAlignment() * 8);
                switch (self.target.cpu.arch) {
                    .aarch64,
                    .aarch64_be,
                    .aarch64_32,
                    => if (size == 128) {
                        abi = size;
                        pref = size;
                    } else switch (self.target.os.tag) {
                        .macos, .ios => {},
                        .uefi, .windows => {
                            pref = size;
                            force_abi = size >= 32;
                        },
                        else => pref = @max(pref, 32),
                    },
                    .arc => if (size <= 64) {
                        abi = @min((std.math.divCeil(u24, size, 8) catch unreachable) * 8, 32);
                        pref = 32;
                        force_abi = true;
                        force_pref = size <= 32;
                    },
                    .bpfeb,
                    .bpfel,
                    .nvptx,
                    .nvptx64,
                    .riscv64,
                    => if (size == 128) {
                        abi = size;
                        pref = size;
                    },
                    .csky => if (size == 32 or size == 64) {
                        abi = 32;
                        pref = 32;
                        force_abi = true;
                        force_pref = true;
                    },
                    .hexagon => force_abi = true,
                    .m68k => if (size <= 32) {
                        abi = @min(size, 16);
                        pref = size;
                        force_abi = true;
                        force_pref = true;
                    } else if (size == 64) {
                        abi = 32;
                        pref = size;
                    },
                    .mips,
                    .mipsel,
                    .mips64,
                    .mips64el,
                    => pref = @max(pref, 32),
                    .s390x => pref = @max(pref, 16),
                    .ve => if (size == 64) {
                        abi = size;
                        pref = size;
                    },
                    .xtensa => if (size <= 64) {
                        pref = @max(size, 32);
                        abi = size;
                        force_abi = size == 64;
                    },
                    else => {},
                }
            },
            .vector => if (self.target.cpu.arch.isArmOrThumb()) {
                switch (size) {
                    128 => abi = 64,
                    else => {},
                }
            } else if ((self.target.cpu.arch.isPPC64() and self.target.os.tag == .linux and
                (size == 256 or size == 512)) or
                (self.target.cpu.arch.isNvptx() and (size == 16 or size == 32)))
            {
                force_abi = true;
                abi = size;
                pref = size;
            } else if (self.target.cpu.arch == .amdgcn and size <= 2048) {
                force_abi = true;
            } else if (self.target.cpu.arch == .csky and (size == 64 or size == 128)) {
                abi = 32;
                pref = 32;
                force_pref = true;
            } else if (self.target.cpu.arch == .hexagon and
                ((size >= 32 and size <= 64) or (size >= 512 and size <= 2048)))
            {
                abi = size;
                pref = size;
                force_pref = true;
            } else if (self.target.cpu.arch == .s390x and size == 128) {
                abi = 64;
                pref = 64;
                force_pref = false;
            } else if (self.target.cpu.arch == .ve and (size >= 64 and size <= 16384)) {
                abi = 64;
                pref = 64;
                force_abi = true;
                force_pref = true;
            },
            .float => switch (self.target.cpu.arch) {
                .aarch64_32, .amdgcn => if (size == 128) {
                    abi = size;
                    pref = size;
                },
                .arc => if (size == 32 or size == 64) {
                    abi = 32;
                    pref = 32;
                    force_abi = true;
                    force_pref = size == 32;
                },
                .avr, .msp430, .sparc64 => if (size != 32 and size != 64) return,
                .csky => if (size == 32 or size == 64) {
                    abi = 32;
                    pref = 32;
                    force_abi = true;
                    force_pref = true;
                },
                .hexagon => if (size == 32 or size == 64) {
                    force_abi = true;
                },
                .ve, .xtensa => if (size == 64) {
                    abi = size;
                    pref = size;
                },
                .wasm32, .wasm64 => if (self.target.os.tag == .emscripten and size == 128) {
                    abi = 64;
                    pref = 64;
                },
                else => {},
            },
            .aggregate => if (self.target.os.tag == .uefi or self.target.os.tag == .windows or
                self.target.cpu.arch.isArmOrThumb())
            {
                pref = @min(pref, self.target.ptrBitWidth());
            } else switch (self.target.cpu.arch) {
                .arc, .csky => {
                    abi = 0;
                    pref = 32;
                },
                .hexagon => {
                    abi = 0;
                    pref = 0;
                },
                .m68k => {
                    abi = 0;
                    pref = 16;
                },
                .msp430 => {
                    abi = 8;
                    pref = 8;
                },
                .s390x => {
                    abi = 8;
                    pref = 16;
                },
                else => {},
            },
        }
        if (kind != .vector and self.target.cpu.arch == .avr) {
            force_abi = true;
            abi = 8;
            pref = 8;
        }
        if (!force_abi and abi == default_abi and pref == default_pref) return;
        try writer.print("-{c}", .{@tagName(kind)[0]});
        if (size != 0) try writer.print("{d}", .{size});
        try writer.print(":{d}", .{abi});
        if (pref != abi or force_pref) try writer.print(":{d}", .{pref});
    }
};

pub const Object = struct {
    gpa: Allocator,
    builder: Builder,

    module: *Module,
    di_builder: ?if (build_options.have_llvm) *llvm.DIBuilder else noreturn,
    /// One of these mappings:
    /// - *Module.File => *DIFile
    /// - *Module.Decl (Fn) => *DISubprogram
    /// - *Module.Decl (Non-Fn) => *DIGlobalVariable
    di_map: if (build_options.have_llvm) std.AutoHashMapUnmanaged(*const anyopaque, *llvm.DINode) else struct {
        const K = *const anyopaque;
        const V = noreturn;

        const Self = @This();

        metadata: ?noreturn = null,
        size: Size = 0,
        available: Size = 0,

        pub const Size = u0;

        pub fn deinit(self: *Self, allocator: Allocator) void {
            _ = allocator;
            self.* = undefined;
        }

        pub fn get(self: Self, key: K) ?V {
            _ = self;
            _ = key;
            return null;
        }
    },
    di_compile_unit: ?if (build_options.have_llvm) *llvm.DICompileUnit else noreturn,
    target_machine: if (build_options.have_llvm) *llvm.TargetMachine else void,
    target_data: if (build_options.have_llvm) *llvm.TargetData else void,
    target: std.Target,
    /// Ideally we would use `llvm_module.getNamedFunction` to go from *Decl to LLVM function,
    /// but that has some downsides:
    /// * we have to compute the fully qualified name every time we want to do the lookup
    /// * for externally linked functions, the name is not fully qualified, but when
    ///   a Decl goes from exported to not exported and vice-versa, we would use the wrong
    ///   version of the name and incorrectly get function not found in the llvm module.
    /// * it works for functions not all globals.
    /// Therefore, this table keeps track of the mapping.
    decl_map: std.AutoHashMapUnmanaged(InternPool.DeclIndex, Builder.Global.Index),
    /// Same deal as `decl_map` but for anonymous declarations, which are always global constants.
    anon_decl_map: std.AutoHashMapUnmanaged(InternPool.Index, Builder.Global.Index),
    /// Serves the same purpose as `decl_map` but only used for the `is_named_enum_value` instruction.
    named_enum_map: std.AutoHashMapUnmanaged(InternPool.DeclIndex, Builder.Function.Index),
    /// Maps Zig types to LLVM types. The table memory is backed by the GPA of
    /// the compiler.
    /// TODO when InternPool garbage collection is implemented, this map needs
    /// to be garbage collected as well.
    type_map: TypeMap,
    di_type_map: DITypeMap,
    /// The LLVM global table which holds the names corresponding to Zig errors.
    /// Note that the values are not added until `emit`, when all errors in
    /// the compilation are known.
    error_name_table: Builder.Variable.Index,
    /// This map is usually very close to empty. It tracks only the cases when a
    /// second extern Decl could not be emitted with the correct name due to a
    /// name collision.
    extern_collisions: std.AutoArrayHashMapUnmanaged(InternPool.DeclIndex, void),

    /// Memoizes a null `?usize` value.
    null_opt_usize: Builder.Constant,

    /// When an LLVM struct type is created, an entry is inserted into this
    /// table for every zig source field of the struct that has a corresponding
    /// LLVM struct field. comptime fields are not included. Zero-bit fields are
    /// mapped to a field at the correct byte, which may be a padding field, or
    /// are not mapped, in which case they are sematically at the end of the
    /// struct.
    /// The value is the LLVM struct field index.
    /// This is denormalized data.
    struct_field_map: std.AutoHashMapUnmanaged(ZigStructField, c_uint),

    const ZigStructField = struct {
        struct_ty: InternPool.Index,
        field_index: u32,
    };

    pub const TypeMap = std.AutoHashMapUnmanaged(InternPool.Index, Builder.Type);

    /// This is an ArrayHashMap as opposed to a HashMap because in `emit` we
    /// want to iterate over it while adding entries to it.
    pub const DITypeMap = std.AutoArrayHashMapUnmanaged(InternPool.Index, AnnotatedDITypePtr);

    pub fn create(arena: Allocator, comp: *Compilation) !*Object {
        if (build_options.only_c) unreachable;
        const gpa = comp.gpa;
        const target = comp.root_mod.resolved_target.result;
        const llvm_target_triple = try targetTriple(arena, target);
        const strip = comp.root_mod.strip;
        const optimize_mode = comp.root_mod.optimize_mode;
        const pic = comp.root_mod.pic;

        var builder = try Builder.init(.{
            .allocator = gpa,
            .use_lib_llvm = comp.config.use_lib_llvm,
            .strip = strip or !comp.config.use_lib_llvm, // TODO
            .name = comp.root_name,
            .target = target,
            .triple = llvm_target_triple,
        });
        errdefer builder.deinit();

        var target_machine: if (build_options.have_llvm) *llvm.TargetMachine else void = undefined;
        var target_data: if (build_options.have_llvm) *llvm.TargetData else void = undefined;
        if (builder.useLibLlvm()) {
            debug_info: {
                switch (comp.config.debug_format) {
                    .strip => break :debug_info,
                    .code_view => builder.llvm.module.?.addModuleCodeViewFlag(),
                    .dwarf => |f| builder.llvm.module.?.addModuleDebugInfoFlag(f == .@"64"),
                }
                builder.llvm.di_builder = builder.llvm.module.?.createDIBuilder(true);

                // Don't use the version string here; LLVM misparses it when it
                // includes the git revision.
                const producer = try builder.fmt("zig {d}.{d}.{d}", .{
                    build_options.semver.major,
                    build_options.semver.minor,
                    build_options.semver.patch,
                });

                // We fully resolve all paths at this point to avoid lack of
                // source line info in stack traces or lack of debugging
                // information which, if relative paths were used, would be
                // very location dependent.
                // TODO: the only concern I have with this is WASI as either host or target, should
                // we leave the paths as relative then?
                // TODO: This is totally wrong. In dwarf, paths are encoded as relative to
                // a particular directory, and then the directory path is specified elsewhere.
                // In the compiler frontend we have it stored correctly in this
                // way already, but here we throw all that sweet information
                // into the garbage can by converting into absolute paths. What
                // a terrible tragedy.
                const compile_unit_dir_z = blk: {
                    if (comp.module) |zcu| m: {
                        const d = try zcu.root_mod.root.joinStringZ(arena, "");
                        if (d.len == 0) break :m;
                        if (std.fs.path.isAbsolute(d)) break :blk d;
                        const realpath = std.fs.realpathAlloc(arena, d) catch break :blk d;
                        break :blk try arena.dupeZ(u8, realpath);
                    }
                    const cwd = try std.process.getCwdAlloc(arena);
                    break :blk try arena.dupeZ(u8, cwd);
                };

                builder.llvm.di_compile_unit = builder.llvm.di_builder.?.createCompileUnit(
                    DW.LANG.C99,
                    builder.llvm.di_builder.?.createFile(comp.root_name, compile_unit_dir_z),
                    producer.slice(&builder).?,
                    optimize_mode != .Debug,
                    "", // flags
                    0, // runtime version
                    "", // split name
                    0, // dwo id
                    true, // emit debug info
                );
            }

            const opt_level: llvm.CodeGenOptLevel = if (optimize_mode == .Debug)
                .None
            else
                .Aggressive;

            const reloc_mode: llvm.RelocMode = if (pic)
                .PIC
            else if (comp.config.link_mode == .Dynamic)
                llvm.RelocMode.DynamicNoPIC
            else
                .Static;

            const code_model: llvm.CodeModel = switch (comp.root_mod.code_model) {
                .default => .Default,
                .tiny => .Tiny,
                .small => .Small,
                .kernel => .Kernel,
                .medium => .Medium,
                .large => .Large,
            };

            // TODO handle float ABI better- it should depend on the ABI portion of std.Target
            const float_abi: llvm.ABIType = .Default;

            target_machine = llvm.TargetMachine.create(
                builder.llvm.target.?,
                builder.target_triple.slice(&builder).?,
                if (target.cpu.model.llvm_name) |s| s.ptr else null,
                comp.root_mod.resolved_target.llvm_cpu_features.?,
                opt_level,
                reloc_mode,
                code_model,
                comp.function_sections,
                comp.data_sections,
                float_abi,
                if (target_util.llvmMachineAbi(target)) |s| s.ptr else null,
            );
            errdefer target_machine.dispose();

            target_data = target_machine.createTargetDataLayout();
            errdefer target_data.dispose();

            builder.llvm.module.?.setModuleDataLayout(target_data);

            if (pic) builder.llvm.module.?.setModulePICLevel();
            if (comp.config.pie) builder.llvm.module.?.setModulePIELevel();
            if (code_model != .Default) builder.llvm.module.?.setModuleCodeModel(code_model);

            if (comp.llvm_opt_bisect_limit >= 0) {
                builder.llvm.context.setOptBisectLimit(comp.llvm_opt_bisect_limit);
            }

            builder.data_layout = try builder.fmt("{}", .{DataLayoutBuilder{ .target = target }});
            if (std.debug.runtime_safety) {
                const rep = target_data.stringRep();
                defer llvm.disposeMessage(rep);
                std.testing.expectEqualStrings(
                    std.mem.span(rep),
                    builder.data_layout.slice(&builder).?,
                ) catch unreachable;
            }
        }

        const obj = try arena.create(Object);
        obj.* = .{
            .gpa = gpa,
            .builder = builder,
            .module = comp.module.?,
            .di_map = .{},
            .di_builder = if (builder.useLibLlvm()) builder.llvm.di_builder else null, // TODO
            .di_compile_unit = if (builder.useLibLlvm()) builder.llvm.di_compile_unit else null,
            .target_machine = target_machine,
            .target_data = target_data,
            .target = target,
            .decl_map = .{},
            .anon_decl_map = .{},
            .named_enum_map = .{},
            .type_map = .{},
            .di_type_map = .{},
            .error_name_table = .none,
            .extern_collisions = .{},
            .null_opt_usize = .no_init,
            .struct_field_map = .{},
        };
        return obj;
    }

    pub fn deinit(self: *Object) void {
        const gpa = self.gpa;
        self.di_map.deinit(gpa);
        self.di_type_map.deinit(gpa);
        if (self.builder.useLibLlvm()) {
            self.target_data.dispose();
            self.target_machine.dispose();
        }
        self.decl_map.deinit(gpa);
        self.anon_decl_map.deinit(gpa);
        self.named_enum_map.deinit(gpa);
        self.type_map.deinit(gpa);
        self.extern_collisions.deinit(gpa);
        self.builder.deinit();
        self.struct_field_map.deinit(gpa);
        self.* = undefined;
    }

    fn genErrorNameTable(o: *Object) Allocator.Error!void {
        // If o.error_name_table is null, then it was not referenced by any instructions.
        if (o.error_name_table == .none) return;

        const mod = o.module;

        const error_name_list = mod.global_error_set.keys();
        const llvm_errors = try mod.gpa.alloc(Builder.Constant, error_name_list.len);
        defer mod.gpa.free(llvm_errors);

        // TODO: Address space
        const slice_ty = Type.slice_const_u8_sentinel_0;
        const llvm_usize_ty = try o.lowerType(Type.usize);
        const llvm_slice_ty = try o.lowerType(slice_ty);
        const llvm_table_ty = try o.builder.arrayType(error_name_list.len, llvm_slice_ty);

        llvm_errors[0] = try o.builder.undefConst(llvm_slice_ty);
        for (llvm_errors[1..], error_name_list[1..]) |*llvm_error, name| {
            const name_string = try o.builder.string(mod.intern_pool.stringToSlice(name));
            const name_init = try o.builder.stringNullConst(name_string);
            const name_variable_index =
                try o.builder.addVariable(.empty, name_init.typeOf(&o.builder), .default);
            try name_variable_index.setInitializer(name_init, &o.builder);
            name_variable_index.setLinkage(.private, &o.builder);
            name_variable_index.setMutability(.constant, &o.builder);
            name_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
            name_variable_index.setAlignment(comptime Builder.Alignment.fromByteUnits(1), &o.builder);

            llvm_error.* = try o.builder.structConst(llvm_slice_ty, &.{
                name_variable_index.toConst(&o.builder),
                try o.builder.intConst(llvm_usize_ty, name_string.slice(&o.builder).?.len),
            });
        }

        const table_variable_index = try o.builder.addVariable(.empty, llvm_table_ty, .default);
        try table_variable_index.setInitializer(
            try o.builder.arrayConst(llvm_table_ty, llvm_errors),
            &o.builder,
        );
        table_variable_index.setLinkage(.private, &o.builder);
        table_variable_index.setMutability(.constant, &o.builder);
        table_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        table_variable_index.setAlignment(
            slice_ty.abiAlignment(mod).toLlvm(),
            &o.builder,
        );

        try o.error_name_table.setInitializer(table_variable_index.toConst(&o.builder), &o.builder);
    }

    fn genCmpLtErrorsLenFunction(o: *Object) !void {
        // If there is no such function in the module, it means the source code does not need it.
        const name = o.builder.stringIfExists(lt_errors_fn_name) orelse return;
        const llvm_fn = o.builder.getGlobal(name) orelse return;
        const mod = o.module;
        const errors_len = mod.global_error_set.count();

        var wip = try Builder.WipFunction.init(&o.builder, llvm_fn.ptrConst(&o.builder).kind.function);
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        // Example source of the following LLVM IR:
        // fn __zig_lt_errors_len(index: u16) bool {
        //     return index < total_errors_len;
        // }

        const lhs = wip.arg(0);
        const rhs = try o.builder.intValue(try o.errorIntType(), errors_len);
        const is_lt = try wip.icmp(.ult, lhs, rhs, "");
        _ = try wip.ret(is_lt);
        try wip.finish();
    }

    fn genModuleLevelAssembly(object: *Object) !void {
        const mod = object.module;

        const writer = object.builder.setModuleAsm();
        for (mod.global_assembly.values()) |assembly| {
            try writer.print("{s}\n", .{assembly});
        }
        try object.builder.finishModuleAsm();
    }

    fn resolveExportExternCollisions(object: *Object) !void {
        const mod = object.module;

        // This map has externs with incorrect symbol names.
        for (object.extern_collisions.keys()) |decl_index| {
            const global = object.decl_map.get(decl_index) orelse continue;
            // Same logic as below but for externs instead of exports.
            const decl_name = object.builder.stringIfExists(mod.intern_pool.stringToSlice(mod.declPtr(decl_index).name)) orelse continue;
            const other_global = object.builder.getGlobal(decl_name) orelse continue;
            if (other_global.toConst().getBase(&object.builder) ==
                global.toConst().getBase(&object.builder)) continue;

            try global.replace(other_global, &object.builder);
        }
        object.extern_collisions.clearRetainingCapacity();

        for (mod.decl_exports.keys(), mod.decl_exports.values()) |decl_index, export_list| {
            const global = object.decl_map.get(decl_index) orelse continue;
            try resolveGlobalCollisions(object, global, export_list.items);
        }

        for (mod.value_exports.keys(), mod.value_exports.values()) |val, export_list| {
            const global = object.anon_decl_map.get(val) orelse continue;
            try resolveGlobalCollisions(object, global, export_list.items);
        }
    }

    fn resolveGlobalCollisions(
        object: *Object,
        global: Builder.Global.Index,
        export_list: []const *Module.Export,
    ) !void {
        const mod = object.module;
        const global_base = global.toConst().getBase(&object.builder);
        for (export_list) |exp| {
            // Detect if the LLVM global has already been created as an extern. In such
            // case, we need to replace all uses of it with this exported global.
            const exp_name = object.builder.stringIfExists(mod.intern_pool.stringToSlice(exp.opts.name)) orelse continue;

            const other_global = object.builder.getGlobal(exp_name) orelse continue;
            if (other_global.toConst().getBase(&object.builder) == global_base) continue;

            try global.takeName(other_global, &object.builder);
            try other_global.replace(global, &object.builder);
            // Problem: now we need to replace in the decl_map that
            // the extern decl index points to this new global. However we don't
            // know the decl index.
            // Even if we did, a future incremental update to the extern would then
            // treat the LLVM global as an extern rather than an export, so it would
            // need a way to check that.
            // This is a TODO that needs to be solved when making
            // the LLVM backend support incremental compilation.
        }
    }

    pub const EmitOptions = struct {
        pre_ir_path: ?[]const u8,
        pre_bc_path: ?[]const u8,
        bin_path: ?[*:0]const u8,
        asm_path: ?[*:0]const u8,
        post_ir_path: ?[*:0]const u8,
        post_bc_path: ?[*:0]const u8,

        is_debug: bool,
        is_small: bool,
        time_report: bool,
        sanitize_thread: bool,
        lto: bool,
    };

    pub fn emit(self: *Object, options: EmitOptions) !void {
        try self.resolveExportExternCollisions();
        try self.genErrorNameTable();
        try self.genCmpLtErrorsLenFunction();
        try self.genModuleLevelAssembly();

        if (self.di_builder) |dib| {
            // When lowering debug info for pointers, we emitted the element types as
            // forward decls. Now we must go flesh those out.
            // Here we iterate over a hash map while modifying it but it is OK because
            // we never add or remove entries during this loop.
            var i: usize = 0;
            while (i < self.di_type_map.count()) : (i += 1) {
                const value_ptr = &self.di_type_map.values()[i];
                const annotated = value_ptr.*;
                if (!annotated.isFwdOnly()) continue;
                const entry: Object.DITypeMap.Entry = .{
                    .key_ptr = &self.di_type_map.keys()[i],
                    .value_ptr = value_ptr,
                };
                _ = try self.lowerDebugTypeImpl(entry, .full, annotated.toDIType());
            }

            dib.finalize();
        }

        if (options.pre_ir_path) |path| {
            if (std.mem.eql(u8, path, "-")) {
                self.builder.dump();
            } else {
                _ = try self.builder.printToFile(path);
            }
        }

        if (options.pre_bc_path) |path| _ = try self.builder.writeBitcodeToFile(path);

        if (std.debug.runtime_safety and !try self.builder.verify()) {
            @panic("LLVM module verification failed");
        }

        const emit_asm_msg = options.asm_path orelse "(none)";
        const emit_bin_msg = options.bin_path orelse "(none)";
        const post_llvm_ir_msg = options.post_ir_path orelse "(none)";
        const post_llvm_bc_msg = options.post_bc_path orelse "(none)";
        log.debug("emit LLVM object asm={s} bin={s} ir={s} bc={s}", .{
            emit_asm_msg, emit_bin_msg, post_llvm_ir_msg, post_llvm_bc_msg,
        });

        if (options.asm_path == null and options.bin_path == null and
            options.post_ir_path == null and options.post_bc_path == null) return;

        if (!self.builder.useLibLlvm()) unreachable; // caught in Compilation.Config.resolve

        // Unfortunately, LLVM shits the bed when we ask for both binary and assembly.
        // So we call the entire pipeline multiple times if this is requested.
        var error_message: [*:0]const u8 = undefined;
        var emit_bin_path = options.bin_path;
        var post_ir_path = options.post_ir_path;
        if (options.asm_path != null and options.bin_path != null) {
            if (self.target_machine.emitToFile(
                self.builder.llvm.module.?,
                &error_message,
                options.is_debug,
                options.is_small,
                options.time_report,
                options.sanitize_thread,
                options.lto,
                null,
                emit_bin_path,
                post_ir_path,
                null,
            )) {
                defer llvm.disposeMessage(error_message);

                log.err("LLVM failed to emit bin={s} ir={s}: {s}", .{
                    emit_bin_msg, post_llvm_ir_msg, error_message,
                });
                return error.FailedToEmit;
            }
            emit_bin_path = null;
            post_ir_path = null;
        }

        if (self.target_machine.emitToFile(
            self.builder.llvm.module.?,
            &error_message,
            options.is_debug,
            options.is_small,
            options.time_report,
            options.sanitize_thread,
            options.lto,
            options.asm_path,
            emit_bin_path,
            post_ir_path,
            options.post_bc_path,
        )) {
            defer llvm.disposeMessage(error_message);

            log.err("LLVM failed to emit asm={s} bin={s} ir={s} bc={s}: {s}", .{
                emit_asm_msg,  emit_bin_msg, post_llvm_ir_msg, post_llvm_bc_msg,
                error_message,
            });
            return error.FailedToEmit;
        }
    }

    pub fn updateFunc(
        o: *Object,
        zcu: *Module,
        func_index: InternPool.Index,
        air: Air,
        liveness: Liveness,
    ) !void {
        const func = zcu.funcInfo(func_index);
        const decl_index = func.owner_decl;
        const decl = zcu.declPtr(decl_index);
        const namespace = zcu.namespacePtr(decl.src_namespace);
        const owner_mod = namespace.file_scope.mod;
        const fn_info = zcu.typeToFunc(decl.ty).?;
        const target = zcu.getTarget();
        const ip = &zcu.intern_pool;

        var dg: DeclGen = .{
            .object = o,
            .decl_index = decl_index,
            .decl = decl,
            .err_msg = null,
        };

        const function_index = try o.resolveLlvmFunction(decl_index);

        var attributes = try function_index.ptrConst(&o.builder).attributes.toWip(&o.builder);
        defer attributes.deinit(&o.builder);

        if (func.analysis(ip).is_noinline) {
            try attributes.addFnAttr(.@"noinline", &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.@"noinline");
        }

        const stack_alignment = func.analysis(ip).stack_alignment;
        if (stack_alignment != .none) {
            try attributes.addFnAttr(.{ .alignstack = stack_alignment.toLlvm() }, &o.builder);
            try attributes.addFnAttr(.@"noinline", &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.alignstack);
        }

        if (func.analysis(ip).is_cold) {
            try attributes.addFnAttr(.cold, &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.cold);
        }

        // TODO: disable this if safety is off for the function scope
        const ssp_buf_size = owner_mod.stack_protector;
        if (ssp_buf_size != 0) {
            try attributes.addFnAttr(.sspstrong, &o.builder);
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("stack-protector-buffer-size"),
                .value = try o.builder.fmt("{d}", .{ssp_buf_size}),
            } }, &o.builder);
        }

        // TODO: disable this if safety is off for the function scope
        if (owner_mod.stack_check) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("probe-stack"),
                .value = try o.builder.string("__zig_probe_stack"),
            } }, &o.builder);
        } else if (target.os.tag == .uefi) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("no-stack-arg-probe"),
                .value = .empty,
            } }, &o.builder);
        }

        if (ip.stringToSliceUnwrap(decl.@"linksection")) |section|
            function_index.setSection(try o.builder.string(section), &o.builder);

        var deinit_wip = true;
        var wip = try Builder.WipFunction.init(&o.builder, function_index);
        defer if (deinit_wip) wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        var llvm_arg_i: u32 = 0;

        // This gets the LLVM values from the function and stores them in `dg.args`.
        const sret = firstParamSRet(fn_info, zcu);
        const ret_ptr: Builder.Value = if (sret) param: {
            const param = wip.arg(llvm_arg_i);
            llvm_arg_i += 1;
            break :param param;
        } else .none;

        if (ccAbiPromoteInt(fn_info.cc, zcu, Type.fromInterned(fn_info.return_type))) |s| switch (s) {
            .signed => try attributes.addRetAttr(.signext, &o.builder),
            .unsigned => try attributes.addRetAttr(.zeroext, &o.builder),
        };

        const comp = zcu.comp;

        const err_return_tracing = Type.fromInterned(fn_info.return_type).isError(zcu) and
            comp.config.any_error_tracing;

        const err_ret_trace: Builder.Value = if (err_return_tracing) param: {
            const param = wip.arg(llvm_arg_i);
            llvm_arg_i += 1;
            break :param param;
        } else .none;

        // This is the list of args we will use that correspond directly to the AIR arg
        // instructions. Depending on the calling convention, this list is not necessarily
        // a bijection with the actual LLVM parameters of the function.
        const gpa = o.gpa;
        var args: std.ArrayListUnmanaged(Builder.Value) = .{};
        defer args.deinit(gpa);

        {
            var it = iterateParamTypes(o, fn_info);
            while (try it.next()) |lowering| {
                try args.ensureUnusedCapacity(gpa, 1);

                switch (lowering) {
                    .no_bits => continue,
                    .byval => {
                        assert(!it.byval_attr);
                        const param_index = it.zig_index - 1;
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                        const param = wip.arg(llvm_arg_i);

                        if (isByRef(param_ty, zcu)) {
                            const alignment = param_ty.abiAlignment(zcu).toLlvm();
                            const param_llvm_ty = param.typeOfWip(&wip);
                            const arg_ptr = try buildAllocaInner(&wip, false, param_llvm_ty, alignment, target);
                            _ = try wip.store(.normal, param, arg_ptr, alignment);
                            args.appendAssumeCapacity(arg_ptr);
                        } else {
                            args.appendAssumeCapacity(param);

                            try o.addByValParamAttrs(&attributes, param_ty, param_index, fn_info, llvm_arg_i);
                        }
                        llvm_arg_i += 1;
                    },
                    .byref => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(param_ty);
                        const param = wip.arg(llvm_arg_i);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();

                        try o.addByRefParamAttrs(&attributes, llvm_arg_i, alignment, it.byval_attr, param_llvm_ty);
                        llvm_arg_i += 1;

                        if (isByRef(param_ty, zcu)) {
                            args.appendAssumeCapacity(param);
                        } else {
                            args.appendAssumeCapacity(try wip.load(.normal, param_llvm_ty, param, alignment, ""));
                        }
                    },
                    .byref_mut => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(param_ty);
                        const param = wip.arg(llvm_arg_i);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();

                        try attributes.addParamAttr(llvm_arg_i, .noundef, &o.builder);
                        llvm_arg_i += 1;

                        if (isByRef(param_ty, zcu)) {
                            args.appendAssumeCapacity(param);
                        } else {
                            args.appendAssumeCapacity(try wip.load(.normal, param_llvm_ty, param, alignment, ""));
                        }
                    },
                    .abi_sized_int => {
                        assert(!it.byval_attr);
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const param_llvm_ty = try o.lowerType(param_ty);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, false, param_llvm_ty, alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                    .slice => {
                        assert(!it.byval_attr);
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const ptr_info = param_ty.ptrInfo(zcu);

                        if (math.cast(u5, it.zig_index - 1)) |i| {
                            if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                                try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                            }
                        }
                        if (param_ty.zigTypeTag(zcu) != .Optional) {
                            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
                        }
                        if (ptr_info.flags.is_const) {
                            try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
                        }
                        const elem_align = (if (ptr_info.flags.alignment != .none)
                            @as(InternPool.Alignment, ptr_info.flags.alignment)
                        else
                            Type.fromInterned(ptr_info.child).abiAlignment(zcu).max(.@"1")).toLlvm();
                        try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align }, &o.builder);
                        const ptr_param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;
                        const len_param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const slice_llvm_ty = try o.lowerType(param_ty);
                        args.appendAssumeCapacity(
                            try wip.buildAggregate(slice_llvm_ty, &.{ ptr_param, len_param }, ""),
                        );
                    },
                    .multiple_llvm_types => {
                        assert(!it.byval_attr);
                        const field_types = it.types_buffer[0..it.types_len];
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(param_ty);
                        const param_alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, false, param_llvm_ty, param_alignment, target);
                        const llvm_ty = try o.builder.structType(.normal, field_types);
                        for (0..field_types.len) |field_i| {
                            const param = wip.arg(llvm_arg_i);
                            llvm_arg_i += 1;
                            const field_ptr = try wip.gepStruct(llvm_ty, arg_ptr, field_i, "");
                            const alignment =
                                Builder.Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8));
                            _ = try wip.store(.normal, param, field_ptr, alignment);
                        }

                        const is_by_ref = isByRef(param_ty, zcu);
                        args.appendAssumeCapacity(if (is_by_ref)
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, param_alignment, ""));
                    },
                    .as_u16 => {
                        assert(!it.byval_attr);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;
                        args.appendAssumeCapacity(try wip.cast(.bitcast, param, .half, ""));
                    },
                    .float_array => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(param_ty);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, false, param_llvm_ty, alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                    .i32_array, .i64_array => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(param_ty);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, false, param_llvm_ty, alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                }
            }
        }

        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);

        var di_file: ?if (build_options.have_llvm) *llvm.DIFile else noreturn = null;
        var di_scope: ?if (build_options.have_llvm) *llvm.DIScope else noreturn = null;

        if (o.di_builder) |dib| {
            di_file = try o.getDIFile(gpa, namespace.file_scope);

            const line_number = decl.src_line + 1;
            const is_internal_linkage = decl.val.getExternFunc(zcu) == null and
                !zcu.decl_exports.contains(decl_index);
            const noret_bit: c_uint = if (fn_info.return_type == .noreturn_type)
                llvm.DIFlags.NoReturn
            else
                0;
            const decl_di_ty = try o.lowerDebugType(decl.ty, .full);
            const subprogram = dib.createFunction(
                di_file.?.toScope(),
                ip.stringToSlice(decl.name),
                function_index.name(&o.builder).slice(&o.builder).?,
                di_file.?,
                line_number,
                decl_di_ty,
                is_internal_linkage,
                true, // is definition
                line_number + func.lbrace_line, // scope line
                llvm.DIFlags.StaticMember | noret_bit,
                owner_mod.optimize_mode != .Debug,
                null, // decl_subprogram
            );
            try o.di_map.put(gpa, decl, subprogram.toNode());

            function_index.toLlvm(&o.builder).fnSetSubprogram(subprogram);

            di_scope = subprogram.toScope();
        }

        var fg: FuncGen = .{
            .gpa = gpa,
            .air = air,
            .liveness = liveness,
            .dg = &dg,
            .wip = wip,
            .ret_ptr = ret_ptr,
            .args = args.items,
            .arg_index = 0,
            .func_inst_table = .{},
            .blocks = .{},
            .sync_scope = if (owner_mod.single_threaded) .singlethread else .system,
            .di_scope = di_scope,
            .di_file = di_file,
            .base_line = dg.decl.src_line,
            .prev_dbg_line = 0,
            .prev_dbg_column = 0,
            .err_ret_trace = err_ret_trace,
        };
        defer fg.deinit();
        deinit_wip = false;

        fg.genBody(air.getMainBody()) catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try zcu.failed_decls.put(zcu.gpa, decl_index, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };

        try fg.wip.finish();

        try o.updateExports(zcu, .{ .decl_index = decl_index }, zcu.getDeclExports(decl_index));
    }

    pub fn updateDecl(self: *Object, module: *Module, decl_index: InternPool.DeclIndex) !void {
        const decl = module.declPtr(decl_index);
        var dg: DeclGen = .{
            .object = self,
            .decl = decl,
            .decl_index = decl_index,
            .err_msg = null,
        };
        dg.genDecl() catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl_index, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };
        try self.updateExports(module, .{ .decl_index = decl_index }, module.getDeclExports(decl_index));
    }

    pub fn updateExports(
        self: *Object,
        mod: *Module,
        exported: Module.Exported,
        exports: []const *Module.Export,
    ) link.File.UpdateExportsError!void {
        const decl_index = switch (exported) {
            .decl_index => |i| i,
            .value => |val| return updateExportedValue(self, mod, val, exports),
        };
        const gpa = mod.gpa;
        // If the module does not already have the function, we ignore this function call
        // because we call `updateExports` at the end of `updateFunc` and `updateDecl`.
        const global_index = self.decl_map.get(decl_index) orelse return;
        const decl = mod.declPtr(decl_index);
        const comp = mod.comp;
        if (decl.isExtern(mod)) {
            const decl_name = decl_name: {
                const decl_name = mod.intern_pool.stringToSlice(decl.name);

                if (mod.getTarget().isWasm() and try decl.isFunction(mod)) {
                    if (mod.intern_pool.stringToSliceUnwrap(decl.getOwnedExternFunc(mod).?.lib_name)) |lib_name| {
                        if (!std.mem.eql(u8, lib_name, "c")) {
                            break :decl_name try self.builder.fmt("{s}|{s}", .{ decl_name, lib_name });
                        }
                    }
                }

                break :decl_name try self.builder.string(decl_name);
            };

            if (self.builder.getGlobal(decl_name)) |other_global| {
                if (other_global != global_index) {
                    try self.extern_collisions.put(gpa, decl_index, {});
                }
            }

            try global_index.rename(decl_name, &self.builder);
            global_index.setLinkage(.external, &self.builder);
            global_index.setUnnamedAddr(.default, &self.builder);
            if (comp.config.dll_export_fns)
                global_index.setDllStorageClass(.default, &self.builder);
            if (self.di_map.get(decl)) |di_node| {
                const decl_name_slice = decl_name.slice(&self.builder).?;
                if (try decl.isFunction(mod)) {
                    const di_func: *llvm.DISubprogram = @ptrCast(di_node);
                    const linkage_name = llvm.MDString.get(
                        self.builder.llvm.context,
                        decl_name_slice.ptr,
                        decl_name_slice.len,
                    );
                    di_func.replaceLinkageName(linkage_name);
                } else {
                    const di_global: *llvm.DIGlobalVariable = @ptrCast(di_node);
                    const linkage_name = llvm.MDString.get(
                        self.builder.llvm.context,
                        decl_name_slice.ptr,
                        decl_name_slice.len,
                    );
                    di_global.replaceLinkageName(linkage_name);
                }
            }
            if (decl.val.getVariable(mod)) |decl_var| {
                global_index.ptrConst(&self.builder).kind.variable.setThreadLocal(
                    if (decl_var.is_threadlocal) .generaldynamic else .default,
                    &self.builder,
                );
                if (decl_var.is_weak_linkage) global_index.setLinkage(.extern_weak, &self.builder);
            }
        } else if (exports.len != 0) {
            const main_exp_name = try self.builder.string(
                mod.intern_pool.stringToSlice(exports[0].opts.name),
            );
            try global_index.rename(main_exp_name, &self.builder);

            if (self.di_map.get(decl)) |di_node| {
                const main_exp_name_slice = main_exp_name.slice(&self.builder).?;
                if (try decl.isFunction(mod)) {
                    const di_func: *llvm.DISubprogram = @ptrCast(di_node);
                    const linkage_name = llvm.MDString.get(
                        self.builder.llvm.context,
                        main_exp_name_slice.ptr,
                        main_exp_name_slice.len,
                    );
                    di_func.replaceLinkageName(linkage_name);
                } else {
                    const di_global: *llvm.DIGlobalVariable = @ptrCast(di_node);
                    const linkage_name = llvm.MDString.get(
                        self.builder.llvm.context,
                        main_exp_name_slice.ptr,
                        main_exp_name_slice.len,
                    );
                    di_global.replaceLinkageName(linkage_name);
                }
            }

            if (decl.val.getVariable(mod)) |decl_var| if (decl_var.is_threadlocal)
                global_index.ptrConst(&self.builder).kind
                    .variable.setThreadLocal(.generaldynamic, &self.builder);

            return updateExportedGlobal(self, mod, global_index, exports);
        } else {
            const fqn = try self.builder.string(
                mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(mod)),
            );
            try global_index.rename(fqn, &self.builder);
            global_index.setLinkage(.internal, &self.builder);
            if (comp.config.dll_export_fns)
                global_index.setDllStorageClass(.default, &self.builder);
            global_index.setUnnamedAddr(.unnamed_addr, &self.builder);
            if (decl.val.getVariable(mod)) |decl_var| {
                const decl_namespace = mod.namespacePtr(decl.src_namespace);
                const single_threaded = decl_namespace.file_scope.mod.single_threaded;
                global_index.ptrConst(&self.builder).kind.variable.setThreadLocal(
                    if (decl_var.is_threadlocal and !single_threaded)
                        .generaldynamic
                    else
                        .default,
                    &self.builder,
                );
            }
        }
    }

    fn updateExportedValue(
        o: *Object,
        mod: *Module,
        exported_value: InternPool.Index,
        exports: []const *Module.Export,
    ) link.File.UpdateExportsError!void {
        const gpa = mod.gpa;
        const main_exp_name = try o.builder.string(
            mod.intern_pool.stringToSlice(exports[0].opts.name),
        );
        const global_index = i: {
            const gop = try o.anon_decl_map.getOrPut(gpa, exported_value);
            if (gop.found_existing) {
                const global_index = gop.value_ptr.*;
                try global_index.rename(main_exp_name, &o.builder);
                break :i global_index;
            }
            const llvm_addr_space = toLlvmAddressSpace(.generic, o.target);
            const variable_index = try o.builder.addVariable(
                main_exp_name,
                try o.lowerType(Type.fromInterned(mod.intern_pool.typeOf(exported_value))),
                llvm_addr_space,
            );
            const global_index = variable_index.ptrConst(&o.builder).global;
            gop.value_ptr.* = global_index;
            // This line invalidates `gop`.
            const init_val = o.lowerValue(exported_value) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.CodegenFail => return error.AnalysisFail,
            };
            try variable_index.setInitializer(init_val, &o.builder);
            break :i global_index;
        };
        return updateExportedGlobal(o, mod, global_index, exports);
    }

    fn updateExportedGlobal(
        o: *Object,
        mod: *Module,
        global_index: Builder.Global.Index,
        exports: []const *Module.Export,
    ) link.File.UpdateExportsError!void {
        global_index.setUnnamedAddr(.default, &o.builder);
        const comp = mod.comp;
        if (comp.config.dll_export_fns)
            global_index.setDllStorageClass(.dllexport, &o.builder);
        global_index.setLinkage(switch (exports[0].opts.linkage) {
            .Internal => unreachable,
            .Strong => .external,
            .Weak => .weak_odr,
            .LinkOnce => .linkonce_odr,
        }, &o.builder);
        global_index.setVisibility(switch (exports[0].opts.visibility) {
            .default => .default,
            .hidden => .hidden,
            .protected => .protected,
        }, &o.builder);
        if (mod.intern_pool.stringToSliceUnwrap(exports[0].opts.section)) |section|
            switch (global_index.ptrConst(&o.builder).kind) {
                .variable => |impl_index| impl_index.setSection(
                    try o.builder.string(section),
                    &o.builder,
                ),
                .function => unreachable,
                .alias => unreachable,
                .replaced => unreachable,
            };

        // If a Decl is exported more than one time (which is rare),
        // we add aliases for all but the first export.
        // TODO LLVM C API does not support deleting aliases.
        // The planned solution to this is https://github.com/ziglang/zig/issues/13265
        // Until then we iterate over existing aliases and make them point
        // to the correct decl, or otherwise add a new alias. Old aliases are leaked.
        for (exports[1..]) |exp| {
            const exp_name = try o.builder.string(mod.intern_pool.stringToSlice(exp.opts.name));
            if (o.builder.getGlobal(exp_name)) |global| {
                switch (global.ptrConst(&o.builder).kind) {
                    .alias => |alias| {
                        alias.setAliasee(global_index.toConst(), &o.builder);
                        continue;
                    },
                    .variable, .function => {},
                    .replaced => unreachable,
                }
            }
            const alias_index = try o.builder.addAlias(
                .empty,
                global_index.typeOf(&o.builder),
                .default,
                global_index.toConst(),
            );
            try alias_index.rename(exp_name, &o.builder);
        }
    }

    pub fn freeDecl(self: *Object, decl_index: InternPool.DeclIndex) void {
        const global = self.decl_map.get(decl_index) orelse return;
        global.delete(&self.builder);
    }

    fn getDIFile(o: *Object, gpa: Allocator, file: *const Module.File) !*llvm.DIFile {
        const gop = try o.di_map.getOrPut(gpa, file);
        errdefer assert(o.di_map.remove(file));
        if (gop.found_existing) {
            return @ptrCast(gop.value_ptr.*);
        }
        const dir_path_z = d: {
            var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const sub_path = std.fs.path.dirname(file.sub_file_path) orelse "";
            const dir_path = try file.mod.root.joinStringZ(gpa, sub_path);
            if (std.fs.path.isAbsolute(dir_path)) break :d dir_path;
            const abs = std.fs.realpath(dir_path, &buffer) catch break :d dir_path;
            gpa.free(dir_path);
            break :d try gpa.dupeZ(u8, abs);
        };
        defer gpa.free(dir_path_z);
        const sub_file_path_z = try gpa.dupeZ(u8, std.fs.path.basename(file.sub_file_path));
        defer gpa.free(sub_file_path_z);
        const di_file = o.di_builder.?.createFile(sub_file_path_z, dir_path_z);
        gop.value_ptr.* = di_file.toNode();
        return di_file;
    }

    const DebugResolveStatus = enum { fwd, full };

    /// In the implementation of this function, it is required to store a forward decl
    /// into `gop` before making any recursive calls (even directly).
    fn lowerDebugType(
        o: *Object,
        ty: Type,
        resolve: DebugResolveStatus,
    ) Allocator.Error!*llvm.DIType {
        const gpa = o.gpa;
        // Be careful not to reference this `gop` variable after any recursive calls
        // to `lowerDebugType`.
        const gop = try o.di_type_map.getOrPut(gpa, ty.toIntern());
        if (gop.found_existing) {
            const annotated = gop.value_ptr.*;
            const di_type = annotated.toDIType();
            if (!annotated.isFwdOnly() or resolve == .fwd) {
                return di_type;
            }
            const entry: Object.DITypeMap.Entry = .{
                .key_ptr = gop.key_ptr,
                .value_ptr = gop.value_ptr,
            };
            return o.lowerDebugTypeImpl(entry, resolve, di_type);
        }
        errdefer assert(o.di_type_map.orderedRemove(ty.toIntern()));
        const entry: Object.DITypeMap.Entry = .{
            .key_ptr = gop.key_ptr,
            .value_ptr = gop.value_ptr,
        };
        return o.lowerDebugTypeImpl(entry, resolve, null);
    }

    /// This is a helper function used by `lowerDebugType`.
    fn lowerDebugTypeImpl(
        o: *Object,
        gop: Object.DITypeMap.Entry,
        resolve: DebugResolveStatus,
        opt_fwd_decl: ?*llvm.DIType,
    ) Allocator.Error!*llvm.DIType {
        const ty = Type.fromInterned(gop.key_ptr.*);
        const gpa = o.gpa;
        const target = o.target;
        const dib = o.di_builder.?;
        const mod = o.module;
        const ip = &mod.intern_pool;
        switch (ty.zigTypeTag(mod)) {
            .Void, .NoReturn => {
                const di_type = dib.createBasicType("void", 0, DW.ATE.signed);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Int => {
                const info = ty.intInfo(mod);
                assert(info.bits != 0);
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const dwarf_encoding: c_uint = switch (info.signedness) {
                    .signed => DW.ATE.signed,
                    .unsigned => DW.ATE.unsigned,
                };
                const di_bits = ty.abiSize(mod) * 8; // lldb cannot handle non-byte sized types
                const di_type = dib.createBasicType(name, di_bits, dwarf_encoding);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Enum => {
                const owner_decl_index = ty.getOwnerDecl(mod);
                const owner_decl = o.module.declPtr(owner_decl_index);

                if (!ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const enum_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(enum_di_ty));
                    return enum_di_ty;
                }

                const enum_type = ip.indexToKey(ty.toIntern()).enum_type;

                const enumerators = try gpa.alloc(*llvm.DIEnumerator, enum_type.names.len);
                defer gpa.free(enumerators);

                const int_ty = Type.fromInterned(enum_type.tag_ty);
                const int_info = ty.intInfo(mod);
                assert(int_info.bits != 0);

                for (enum_type.names.get(ip), 0..) |field_name_ip, i| {
                    const field_name_z = ip.stringToSlice(field_name_ip);

                    var bigint_space: Value.BigIntSpace = undefined;
                    const bigint = if (enum_type.values.len != 0)
                        Value.fromInterned(enum_type.values.get(ip)[i]).toBigInt(&bigint_space, mod)
                    else
                        std.math.big.int.Mutable.init(&bigint_space.limbs, i).toConst();

                    if (bigint.limbs.len == 1) {
                        enumerators[i] = dib.createEnumerator(field_name_z, bigint.limbs[0], int_info.signedness == .unsigned);
                        continue;
                    }
                    if (@sizeOf(usize) == @sizeOf(u64)) {
                        enumerators[i] = dib.createEnumerator2(
                            field_name_z,
                            @intCast(bigint.limbs.len),
                            bigint.limbs.ptr,
                            int_info.bits,
                            int_info.signedness == .unsigned,
                        );
                        continue;
                    }
                    @panic("TODO implement bigint debug enumerators to llvm int for 32-bit compiler builds");
                }

                const di_file = try o.getDIFile(gpa, mod.namespacePtr(owner_decl.src_namespace).file_scope);
                const di_scope = try o.namespaceToDebugScope(owner_decl.src_namespace);

                const name = try o.allocTypeName(ty);
                defer gpa.free(name);

                const enum_di_ty = dib.createEnumerationType(
                    di_scope,
                    name,
                    di_file,
                    owner_decl.src_node + 1,
                    ty.abiSize(mod) * 8,
                    ty.abiAlignment(mod).toByteUnits(0) * 8,
                    enumerators.ptr,
                    @intCast(enumerators.len),
                    try o.lowerDebugType(int_ty, .full),
                    "",
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(enum_di_ty));
                return enum_di_ty;
            },
            .Float => {
                const bits = ty.floatBits(target);
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const di_type = dib.createBasicType(name, bits, DW.ATE.float);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Bool => {
                const di_bits = 8; // lldb cannot handle non-byte sized types
                const di_type = dib.createBasicType("bool", di_bits, DW.ATE.boolean);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Pointer => {
                // Normalize everything that the debug info does not represent.
                const ptr_info = ty.ptrInfo(mod);

                if (ptr_info.sentinel != .none or
                    ptr_info.flags.address_space != .generic or
                    ptr_info.packed_offset.bit_offset != 0 or
                    ptr_info.packed_offset.host_size != 0 or
                    ptr_info.flags.vector_index != .none or
                    ptr_info.flags.is_allowzero or
                    ptr_info.flags.is_const or
                    ptr_info.flags.is_volatile or
                    ptr_info.flags.size == .Many or ptr_info.flags.size == .C or
                    !Type.fromInterned(ptr_info.child).hasRuntimeBitsIgnoreComptime(mod))
                {
                    const bland_ptr_ty = try mod.ptrType(.{
                        .child = if (!Type.fromInterned(ptr_info.child).hasRuntimeBitsIgnoreComptime(mod))
                            .anyopaque_type
                        else
                            ptr_info.child,
                        .flags = .{
                            .alignment = ptr_info.flags.alignment,
                            .size = switch (ptr_info.flags.size) {
                                .Many, .C, .One => .One,
                                .Slice => .Slice,
                            },
                        },
                    });
                    const ptr_di_ty = try o.lowerDebugType(bland_ptr_ty, resolve);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.init(ptr_di_ty, resolve));
                    return ptr_di_ty;
                }

                if (ty.isSlice(mod)) {
                    const ptr_ty = ty.slicePtrFieldType(mod);
                    const len_ty = Type.usize;

                    const name = try o.allocTypeName(ty);
                    defer gpa.free(name);
                    const di_file: ?*llvm.DIFile = null;
                    const line = 0;
                    const compile_unit_scope = o.di_compile_unit.?.toScope();

                    const fwd_decl = opt_fwd_decl orelse blk: {
                        const fwd_decl = dib.createReplaceableCompositeType(
                            DW.TAG.structure_type,
                            name.ptr,
                            compile_unit_scope,
                            di_file,
                            line,
                        );
                        gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                        if (resolve == .fwd) return fwd_decl;
                        break :blk fwd_decl;
                    };

                    const ptr_size = ptr_ty.abiSize(mod);
                    const ptr_align = ptr_ty.abiAlignment(mod);
                    const len_size = len_ty.abiSize(mod);
                    const len_align = len_ty.abiAlignment(mod);

                    var offset: u64 = 0;
                    offset += ptr_size;
                    offset = len_align.forward(offset);
                    const len_offset = offset;

                    const fields: [2]*llvm.DIType = .{
                        dib.createMemberType(
                            fwd_decl.toScope(),
                            "ptr",
                            di_file,
                            line,
                            ptr_size * 8, // size in bits
                            ptr_align.toByteUnits(0) * 8, // align in bits
                            0, // offset in bits
                            0, // flags
                            try o.lowerDebugType(ptr_ty, .full),
                        ),
                        dib.createMemberType(
                            fwd_decl.toScope(),
                            "len",
                            di_file,
                            line,
                            len_size * 8, // size in bits
                            len_align.toByteUnits(0) * 8, // align in bits
                            len_offset * 8, // offset in bits
                            0, // flags
                            try o.lowerDebugType(len_ty, .full),
                        ),
                    };

                    const full_di_ty = dib.createStructType(
                        compile_unit_scope,
                        name.ptr,
                        di_file,
                        line,
                        ty.abiSize(mod) * 8, // size in bits
                        ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                        0, // flags
                        null, // derived from
                        &fields,
                        fields.len,
                        0, // run time lang
                        null, // vtable holder
                        "", // unique id
                    );
                    dib.replaceTemporary(fwd_decl, full_di_ty);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                    return full_di_ty;
                }

                const elem_di_ty = try o.lowerDebugType(Type.fromInterned(ptr_info.child), .fwd);
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const ptr_di_ty = dib.createPointerType(
                    elem_di_ty,
                    target.ptrBitWidth(),
                    ty.ptrAlignment(mod).toByteUnits(0) * 8,
                    name,
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(ptr_di_ty));
                return ptr_di_ty;
            },
            .Opaque => {
                if (ty.toIntern() == .anyopaque_type) {
                    const di_ty = dib.createBasicType("anyopaque", 0, DW.ATE.signed);
                    gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                    return di_ty;
                }
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const owner_decl_index = ty.getOwnerDecl(mod);
                const owner_decl = o.module.declPtr(owner_decl_index);
                const opaque_di_ty = dib.createForwardDeclType(
                    DW.TAG.structure_type,
                    name,
                    try o.namespaceToDebugScope(owner_decl.src_namespace),
                    try o.getDIFile(gpa, mod.namespacePtr(owner_decl.src_namespace).file_scope),
                    owner_decl.src_node + 1,
                );
                // The recursive call to `lowerDebugType` va `namespaceToDebugScope`
                // means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(opaque_di_ty));
                return opaque_di_ty;
            },
            .Array => {
                const array_di_ty = dib.createArrayType(
                    ty.abiSize(mod) * 8,
                    ty.abiAlignment(mod).toByteUnits(0) * 8,
                    try o.lowerDebugType(ty.childType(mod), .full),
                    @intCast(ty.arrayLen(mod)),
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(array_di_ty));
                return array_di_ty;
            },
            .Vector => {
                const elem_ty = ty.elemType2(mod);
                // Vector elements cannot be padded since that would make
                // @bitSizOf(elem) * len > @bitSizOf(vec).
                // Neither gdb nor lldb seem to be able to display non-byte sized
                // vectors properly.
                const elem_di_type = switch (elem_ty.zigTypeTag(mod)) {
                    .Int => blk: {
                        const info = elem_ty.intInfo(mod);
                        assert(info.bits != 0);
                        const name = try o.allocTypeName(ty);
                        defer gpa.free(name);
                        const dwarf_encoding: c_uint = switch (info.signedness) {
                            .signed => DW.ATE.signed,
                            .unsigned => DW.ATE.unsigned,
                        };
                        break :blk dib.createBasicType(name, info.bits, dwarf_encoding);
                    },
                    .Bool => dib.createBasicType("bool", 1, DW.ATE.boolean),
                    else => try o.lowerDebugType(ty.childType(mod), .full),
                };

                const vector_di_ty = dib.createVectorType(
                    ty.abiSize(mod) * 8,
                    @intCast(ty.abiAlignment(mod).toByteUnits(0) * 8),
                    elem_di_type,
                    ty.vectorLen(mod),
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(vector_di_ty));
                return vector_di_ty;
            },
            .Optional => {
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const child_ty = ty.optionalChild(mod);
                if (!child_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const di_bits = 8; // lldb cannot handle non-byte sized types
                    const di_ty = dib.createBasicType(name, di_bits, DW.ATE.boolean);
                    gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                    return di_ty;
                }
                if (ty.optionalReprIsPayload(mod)) {
                    const ptr_di_ty = try o.lowerDebugType(child_ty, resolve);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.init(ptr_di_ty, resolve));
                    return ptr_di_ty;
                }

                const di_file: ?*llvm.DIFile = null;
                const line = 0;
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        di_file,
                        line,
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                const non_null_ty = Type.u8;
                const payload_size = child_ty.abiSize(mod);
                const payload_align = child_ty.abiAlignment(mod);
                const non_null_size = non_null_ty.abiSize(mod);
                const non_null_align = non_null_ty.abiAlignment(mod);

                var offset: u64 = 0;
                offset += payload_size;
                offset = non_null_align.forward(offset);
                const non_null_offset = offset;

                const fields: [2]*llvm.DIType = .{
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "data",
                        di_file,
                        line,
                        payload_size * 8, // size in bits
                        payload_align.toByteUnits(0) * 8, // align in bits
                        0, // offset in bits
                        0, // flags
                        try o.lowerDebugType(child_ty, .full),
                    ),
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "some",
                        di_file,
                        line,
                        non_null_size * 8, // size in bits
                        non_null_align.toByteUnits(0) * 8, // align in bits
                        non_null_offset * 8, // offset in bits
                        0, // flags
                        try o.lowerDebugType(non_null_ty, .full),
                    ),
                };

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    di_file,
                    line,
                    ty.abiSize(mod) * 8, // size in bits
                    ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &fields,
                    fields.len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                return full_di_ty;
            },
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const err_set_di_ty = try o.lowerDebugType(Type.anyerror, .full);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(err_set_di_ty));
                    return err_set_di_ty;
                }
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);
                const di_file: ?*llvm.DIFile = null;
                const line = 0;
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        di_file,
                        line,
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                const error_size = Type.anyerror.abiSize(mod);
                const error_align = Type.anyerror.abiAlignment(mod);
                const payload_size = payload_ty.abiSize(mod);
                const payload_align = payload_ty.abiAlignment(mod);

                var error_index: u32 = undefined;
                var payload_index: u32 = undefined;
                var error_offset: u64 = undefined;
                var payload_offset: u64 = undefined;
                if (error_align.compare(.gt, payload_align)) {
                    error_index = 0;
                    payload_index = 1;
                    error_offset = 0;
                    payload_offset = payload_align.forward(error_size);
                } else {
                    payload_index = 0;
                    error_index = 1;
                    payload_offset = 0;
                    error_offset = error_align.forward(payload_size);
                }

                var fields: [2]*llvm.DIType = undefined;
                fields[error_index] = dib.createMemberType(
                    fwd_decl.toScope(),
                    "tag",
                    di_file,
                    line,
                    error_size * 8, // size in bits
                    error_align.toByteUnits(0) * 8, // align in bits
                    error_offset * 8, // offset in bits
                    0, // flags
                    try o.lowerDebugType(Type.anyerror, .full),
                );
                fields[payload_index] = dib.createMemberType(
                    fwd_decl.toScope(),
                    "value",
                    di_file,
                    line,
                    payload_size * 8, // size in bits
                    payload_align.toByteUnits(0) * 8, // align in bits
                    payload_offset * 8, // offset in bits
                    0, // flags
                    try o.lowerDebugType(payload_ty, .full),
                );

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    di_file,
                    line,
                    ty.abiSize(mod) * 8, // size in bits
                    ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &fields,
                    fields.len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                return full_di_ty;
            },
            .ErrorSet => {
                // TODO make this a proper enum with all the error codes in it.
                // will need to consider how to take incremental compilation into account.
                const di_ty = dib.createBasicType("anyerror", 16, DW.ATE.unsigned);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                return di_ty;
            },
            .Struct => {
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const name = try o.allocTypeName(ty);
                defer gpa.free(name);

                if (mod.typeToPackedStruct(ty)) |struct_type| {
                    const backing_int_ty = struct_type.backingIntType(ip).*;
                    if (backing_int_ty != .none) {
                        const info = Type.fromInterned(backing_int_ty).intInfo(mod);
                        const dwarf_encoding: c_uint = switch (info.signedness) {
                            .signed => DW.ATE.signed,
                            .unsigned => DW.ATE.unsigned,
                        };
                        const di_bits = ty.abiSize(mod) * 8; // lldb cannot handle non-byte sized types
                        const di_ty = dib.createBasicType(name, di_bits, dwarf_encoding);
                        gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                        return di_ty;
                    }
                }

                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        null, // file
                        0, // line
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                switch (ip.indexToKey(ty.toIntern())) {
                    .anon_struct_type => |tuple| {
                        var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                        defer di_fields.deinit(gpa);

                        try di_fields.ensureUnusedCapacity(gpa, tuple.types.len);

                        comptime assert(struct_layout_version == 2);
                        var offset: u64 = 0;

                        for (tuple.types.get(ip), tuple.values.get(ip), 0..) |field_ty, field_val, i| {
                            if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

                            const field_size = Type.fromInterned(field_ty).abiSize(mod);
                            const field_align = Type.fromInterned(field_ty).abiAlignment(mod);
                            const field_offset = field_align.forward(offset);
                            offset = field_offset + field_size;

                            const field_name = if (tuple.names.len != 0)
                                ip.stringToSlice(tuple.names.get(ip)[i])
                            else
                                try std.fmt.allocPrintZ(gpa, "{d}", .{i});
                            defer if (tuple.names.len == 0) gpa.free(field_name);

                            try di_fields.append(gpa, dib.createMemberType(
                                fwd_decl.toScope(),
                                field_name,
                                null, // file
                                0, // line
                                field_size * 8, // size in bits
                                field_align.toByteUnits(0) * 8, // align in bits
                                field_offset * 8, // offset in bits
                                0, // flags
                                try o.lowerDebugType(Type.fromInterned(field_ty), .full),
                            ));
                        }

                        const full_di_ty = dib.createStructType(
                            compile_unit_scope,
                            name.ptr,
                            null, // file
                            0, // line
                            ty.abiSize(mod) * 8, // size in bits
                            ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                            0, // flags
                            null, // derived from
                            di_fields.items.ptr,
                            @intCast(di_fields.items.len),
                            0, // run time lang
                            null, // vtable holder
                            "", // unique id
                        );
                        dib.replaceTemporary(fwd_decl, full_di_ty);
                        // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                        try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                        return full_di_ty;
                    },
                    .struct_type => |struct_type| {
                        if (!struct_type.haveFieldTypes(ip)) {
                            // This can happen if a struct type makes it all the way to
                            // flush() without ever being instantiated or referenced (even
                            // via pointer). The only reason we are hearing about it now is
                            // that it is being used as a namespace to put other debug types
                            // into. Therefore we can satisfy this by making an empty namespace,
                            // rather than changing the frontend to unnecessarily resolve the
                            // struct field types.
                            const owner_decl_index = ty.getOwnerDecl(mod);
                            const struct_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                            dib.replaceTemporary(fwd_decl, struct_di_ty);
                            // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                            // means we can't use `gop` anymore.
                            try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(struct_di_ty));
                            return struct_di_ty;
                        }
                    },
                    else => {},
                }

                if (!ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const owner_decl_index = ty.getOwnerDecl(mod);
                    const struct_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    dib.replaceTemporary(fwd_decl, struct_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(struct_di_ty));
                    return struct_di_ty;
                }

                const struct_type = mod.typeToStruct(ty).?;

                var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                defer di_fields.deinit(gpa);

                try di_fields.ensureUnusedCapacity(gpa, struct_type.field_types.len);

                comptime assert(struct_layout_version == 2);
                var it = struct_type.iterateRuntimeOrder(ip);
                while (it.next()) |field_index| {
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                    const field_size = field_ty.abiSize(mod);
                    const field_align = mod.structFieldAlignment(
                        struct_type.fieldAlign(ip, field_index),
                        field_ty,
                        struct_type.layout,
                    );
                    const field_offset = ty.structFieldOffset(field_index, mod);

                    const field_name = struct_type.fieldName(ip, field_index).unwrap() orelse
                        try ip.getOrPutStringFmt(gpa, "{d}", .{field_index});

                    const field_di_ty = try o.lowerDebugType(field_ty, .full);

                    try di_fields.append(gpa, dib.createMemberType(
                        fwd_decl.toScope(),
                        ip.stringToSlice(field_name),
                        null, // file
                        0, // line
                        field_size * 8, // size in bits
                        field_align.toByteUnits(0) * 8, // align in bits
                        field_offset * 8, // offset in bits
                        0, // flags
                        field_di_ty,
                    ));
                }

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    null, // file
                    0, // line
                    ty.abiSize(mod) * 8, // size in bits
                    ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    di_fields.items.ptr,
                    @intCast(di_fields.items.len),
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                return full_di_ty;
            },
            .Union => {
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const owner_decl_index = ty.getOwnerDecl(mod);

                const name = try o.allocTypeName(ty);
                defer gpa.free(name);

                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        o.di_compile_unit.?.toScope(),
                        null, // file
                        0, // line
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                const union_type = ip.indexToKey(ty.toIntern()).union_type;
                if (!union_type.haveFieldTypes(ip) or !ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const union_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    dib.replaceTemporary(fwd_decl, union_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(union_di_ty));
                    return union_di_ty;
                }

                const union_obj = ip.loadUnionType(union_type);
                const layout = mod.getUnionLayout(union_obj);

                if (layout.payload_size == 0) {
                    const tag_di_ty = try o.lowerDebugType(Type.fromInterned(union_obj.enum_tag_ty), .full);
                    const di_fields = [_]*llvm.DIType{tag_di_ty};
                    const full_di_ty = dib.createStructType(
                        compile_unit_scope,
                        name.ptr,
                        null, // file
                        0, // line
                        ty.abiSize(mod) * 8, // size in bits
                        ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                        0, // flags
                        null, // derived from
                        &di_fields,
                        di_fields.len,
                        0, // run time lang
                        null, // vtable holder
                        "", // unique id
                    );
                    dib.replaceTemporary(fwd_decl, full_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                    return full_di_ty;
                }

                var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                defer di_fields.deinit(gpa);

                try di_fields.ensureUnusedCapacity(gpa, union_obj.field_names.len);

                for (0..union_obj.field_names.len) |field_index| {
                    const field_ty = union_obj.field_types.get(ip)[field_index];
                    if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) continue;

                    const field_size = Type.fromInterned(field_ty).abiSize(mod);
                    const field_align = mod.unionFieldNormalAlignment(union_obj, @intCast(field_index));

                    const field_di_ty = try o.lowerDebugType(Type.fromInterned(field_ty), .full);
                    const field_name = union_obj.field_names.get(ip)[field_index];
                    di_fields.appendAssumeCapacity(dib.createMemberType(
                        fwd_decl.toScope(),
                        ip.stringToSlice(field_name),
                        null, // file
                        0, // line
                        field_size * 8, // size in bits
                        field_align.toByteUnits(0) * 8, // align in bits
                        0, // offset in bits
                        0, // flags
                        field_di_ty,
                    ));
                }

                var union_name_buf: ?[:0]const u8 = null;
                defer if (union_name_buf) |buf| gpa.free(buf);
                const union_name = if (layout.tag_size == 0) name else name: {
                    union_name_buf = try std.fmt.allocPrintZ(gpa, "{s}:Payload", .{name});
                    break :name union_name_buf.?;
                };

                const union_di_ty = dib.createUnionType(
                    compile_unit_scope,
                    union_name.ptr,
                    null, // file
                    0, // line
                    ty.abiSize(mod) * 8, // size in bits
                    ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                    0, // flags
                    di_fields.items.ptr,
                    @intCast(di_fields.items.len),
                    0, // run time lang
                    "", // unique id
                );

                if (layout.tag_size == 0) {
                    dib.replaceTemporary(fwd_decl, union_di_ty);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(union_di_ty));
                    return union_di_ty;
                }

                var tag_offset: u64 = undefined;
                var payload_offset: u64 = undefined;
                if (layout.tag_align.compare(.gte, layout.payload_align)) {
                    tag_offset = 0;
                    payload_offset = layout.payload_align.forward(layout.tag_size);
                } else {
                    payload_offset = 0;
                    tag_offset = layout.tag_align.forward(layout.payload_size);
                }

                const tag_di = dib.createMemberType(
                    fwd_decl.toScope(),
                    "tag",
                    null, // file
                    0, // line
                    layout.tag_size * 8,
                    layout.tag_align.toByteUnits(0) * 8,
                    tag_offset * 8, // offset in bits
                    0, // flags
                    try o.lowerDebugType(Type.fromInterned(union_obj.enum_tag_ty), .full),
                );

                const payload_di = dib.createMemberType(
                    fwd_decl.toScope(),
                    "payload",
                    null, // file
                    0, // line
                    layout.payload_size * 8, // size in bits
                    layout.payload_align.toByteUnits(0) * 8,
                    payload_offset * 8, // offset in bits
                    0, // flags
                    union_di_ty,
                );

                const full_di_fields: [2]*llvm.DIType =
                    if (layout.tag_align.compare(.gte, layout.payload_align))
                    .{ tag_di, payload_di }
                else
                    .{ payload_di, tag_di };

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    null, // file
                    0, // line
                    ty.abiSize(mod) * 8, // size in bits
                    ty.abiAlignment(mod).toByteUnits(0) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &full_di_fields,
                    full_di_fields.len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(full_di_ty));
                return full_di_ty;
            },
            .Fn => {
                const fn_info = mod.typeToFunc(ty).?;

                var param_di_types = std.ArrayList(*llvm.DIType).init(gpa);
                defer param_di_types.deinit();

                // Return type goes first.
                if (Type.fromInterned(fn_info.return_type).hasRuntimeBitsIgnoreComptime(mod)) {
                    const sret = firstParamSRet(fn_info, mod);
                    const di_ret_ty = if (sret) Type.void else Type.fromInterned(fn_info.return_type);
                    try param_di_types.append(try o.lowerDebugType(di_ret_ty, .full));

                    if (sret) {
                        const ptr_ty = try mod.singleMutPtrType(Type.fromInterned(fn_info.return_type));
                        try param_di_types.append(try o.lowerDebugType(ptr_ty, .full));
                    }
                } else {
                    try param_di_types.append(try o.lowerDebugType(Type.void, .full));
                }

                if (Type.fromInterned(fn_info.return_type).isError(mod) and
                    o.module.comp.config.any_error_tracing)
                {
                    const ptr_ty = try mod.singleMutPtrType(try o.getStackTraceType());
                    try param_di_types.append(try o.lowerDebugType(ptr_ty, .full));
                }

                for (0..fn_info.param_types.len) |i| {
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[i]);
                    if (!param_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                    if (isByRef(param_ty, mod)) {
                        const ptr_ty = try mod.singleMutPtrType(param_ty);
                        try param_di_types.append(try o.lowerDebugType(ptr_ty, .full));
                    } else {
                        try param_di_types.append(try o.lowerDebugType(param_ty, .full));
                    }
                }

                const fn_di_ty = dib.createSubroutineType(
                    param_di_types.items.ptr,
                    @intCast(param_di_types.items.len),
                    0,
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.put(gpa, ty.toIntern(), AnnotatedDITypePtr.initFull(fn_di_ty));
                return fn_di_ty;
            },
            .ComptimeInt => unreachable,
            .ComptimeFloat => unreachable,
            .Type => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .EnumLiteral => unreachable,

            .Frame => @panic("TODO implement lowerDebugType for Frame types"),
            .AnyFrame => @panic("TODO implement lowerDebugType for AnyFrame types"),
        }
    }

    fn namespaceToDebugScope(o: *Object, namespace_index: InternPool.NamespaceIndex) !*llvm.DIScope {
        const mod = o.module;
        const namespace = mod.namespacePtr(namespace_index);
        if (namespace.parent == .none) {
            const di_file = try o.getDIFile(o.gpa, namespace.file_scope);
            return di_file.toScope();
        }
        const di_type = try o.lowerDebugType(namespace.ty, .fwd);
        return di_type.toScope();
    }

    /// This is to be used instead of void for debug info types, to avoid tripping
    /// Assertion `!isa<DIType>(Scope) && "shouldn't make a namespace scope for a type"'
    /// when targeting CodeView (Windows).
    fn makeEmptyNamespaceDIType(o: *Object, decl_index: InternPool.DeclIndex) !*llvm.DIType {
        const mod = o.module;
        const decl = mod.declPtr(decl_index);
        const fields: [0]*llvm.DIType = .{};
        const di_scope = try o.namespaceToDebugScope(decl.src_namespace);
        return o.di_builder.?.createStructType(
            di_scope,
            mod.intern_pool.stringToSlice(decl.name), // TODO use fully qualified name
            try o.getDIFile(o.gpa, mod.namespacePtr(decl.src_namespace).file_scope),
            decl.src_line + 1,
            0, // size in bits
            0, // align in bits
            0, // flags
            null, // derived from
            undefined, // TODO should be able to pass &fields,
            fields.len,
            0, // run time lang
            null, // vtable holder
            "", // unique id
        );
    }

    fn getStackTraceType(o: *Object) Allocator.Error!Type {
        const mod = o.module;

        const std_mod = mod.std_mod;
        const std_file = (mod.importPkg(std_mod) catch unreachable).file;

        const builtin_str = try mod.intern_pool.getOrPutString(mod.gpa, "builtin");
        const std_namespace = mod.namespacePtr(mod.declPtr(std_file.root_decl.unwrap().?).src_namespace);
        const builtin_decl = std_namespace.decls
            .getKeyAdapted(builtin_str, Module.DeclAdapter{ .mod = mod }).?;

        const stack_trace_str = try mod.intern_pool.getOrPutString(mod.gpa, "StackTrace");
        // buffer is only used for int_type, `builtin` is a struct.
        const builtin_ty = mod.declPtr(builtin_decl).val.toType();
        const builtin_namespace = builtin_ty.getNamespace(mod).?;
        const stack_trace_decl_index = builtin_namespace.decls
            .getKeyAdapted(stack_trace_str, Module.DeclAdapter{ .mod = mod }).?;
        const stack_trace_decl = mod.declPtr(stack_trace_decl_index);

        // Sema should have ensured that StackTrace was analyzed.
        assert(stack_trace_decl.has_tv);
        return stack_trace_decl.val.toType();
    }

    fn allocTypeName(o: *Object, ty: Type) Allocator.Error![:0]const u8 {
        var buffer = std.ArrayList(u8).init(o.gpa);
        errdefer buffer.deinit();
        try ty.print(buffer.writer(), o.module);
        return buffer.toOwnedSliceSentinel(0);
    }

    /// If the llvm function does not exist, create it.
    /// Note that this can be called before the function's semantic analysis has
    /// completed, so if any attributes rely on that, they must be done in updateFunc, not here.
    fn resolveLlvmFunction(
        o: *Object,
        decl_index: InternPool.DeclIndex,
    ) Allocator.Error!Builder.Function.Index {
        const zcu = o.module;
        const ip = &zcu.intern_pool;
        const gpa = o.gpa;
        const decl = zcu.declPtr(decl_index);
        const namespace = zcu.namespacePtr(decl.src_namespace);
        const owner_mod = namespace.file_scope.mod;
        const zig_fn_type = decl.ty;
        const gop = try o.decl_map.getOrPut(gpa, decl_index);
        if (gop.found_existing) return gop.value_ptr.ptr(&o.builder).kind.function;

        assert(decl.has_tv);
        const fn_info = zcu.typeToFunc(zig_fn_type).?;
        const target = owner_mod.resolved_target.result;
        const sret = firstParamSRet(fn_info, zcu);

        const function_index = try o.builder.addFunction(
            try o.lowerType(zig_fn_type),
            try o.builder.string(ip.stringToSlice(try decl.getFullyQualifiedName(zcu))),
            toLlvmAddressSpace(decl.@"addrspace", target),
        );
        gop.value_ptr.* = function_index.ptrConst(&o.builder).global;

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);

        const is_extern = decl.isExtern(zcu);
        if (!is_extern) {
            function_index.setLinkage(.internal, &o.builder);
            function_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        } else {
            if (target.isWasm()) {
                try attributes.addFnAttr(.{ .string = .{
                    .kind = try o.builder.string("wasm-import-name"),
                    .value = try o.builder.string(ip.stringToSlice(decl.name)),
                } }, &o.builder);
                if (ip.stringToSliceUnwrap(decl.getOwnedExternFunc(zcu).?.lib_name)) |lib_name| {
                    if (!std.mem.eql(u8, lib_name, "c")) try attributes.addFnAttr(.{ .string = .{
                        .kind = try o.builder.string("wasm-import-module"),
                        .value = try o.builder.string(lib_name),
                    } }, &o.builder);
                }
            }
        }

        var llvm_arg_i: u32 = 0;
        if (sret) {
            // Sret pointers must not be address 0
            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);

            const raw_llvm_ret_ty = try o.lowerType(Type.fromInterned(fn_info.return_type));
            try attributes.addParamAttr(llvm_arg_i, .{ .sret = raw_llvm_ret_ty }, &o.builder);

            llvm_arg_i += 1;
        }

        const err_return_tracing = Type.fromInterned(fn_info.return_type).isError(zcu) and
            zcu.comp.config.any_error_tracing;

        if (err_return_tracing) {
            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            llvm_arg_i += 1;
        }

        switch (fn_info.cc) {
            .Unspecified, .Inline => function_index.setCallConv(.fastcc, &o.builder),
            .Naked => try attributes.addFnAttr(.naked, &o.builder),
            .Async => {
                function_index.setCallConv(.fastcc, &o.builder);
                @panic("TODO: LLVM backend lower async function");
            },
            else => function_index.setCallConv(toLlvmCallConv(fn_info.cc, target), &o.builder),
        }

        if (fn_info.alignment != .none)
            function_index.setAlignment(fn_info.alignment.toLlvm(), &o.builder);

        // Function attributes that are independent of analysis results of the function body.
        try o.addCommonFnAttributes(&attributes, owner_mod);

        if (fn_info.return_type == .noreturn_type) try attributes.addFnAttr(.noreturn, &o.builder);

        // Add parameter attributes. We handle only the case of extern functions (no body)
        // because functions with bodies are handled in `updateFunc`.
        if (is_extern) {
            var it = iterateParamTypes(o, fn_info);
            it.llvm_index = llvm_arg_i;
            while (try it.next()) |lowering| switch (lowering) {
                .byval => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    if (!isByRef(param_ty, zcu)) {
                        try o.addByValParamAttrs(&attributes, param_ty, param_index, fn_info, it.llvm_index - 1);
                    }
                },
                .byref => {
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                    const param_llvm_ty = try o.lowerType(param_ty);
                    const alignment = param_ty.abiAlignment(zcu);
                    try o.addByRefParamAttrs(&attributes, it.llvm_index - 1, alignment.toLlvm(), it.byval_attr, param_llvm_ty);
                },
                .byref_mut => try attributes.addParamAttr(it.llvm_index - 1, .noundef, &o.builder),
                // No attributes needed for these.
                .no_bits,
                .abi_sized_int,
                .multiple_llvm_types,
                .as_u16,
                .float_array,
                .i32_array,
                .i64_array,
                => continue,

                .slice => unreachable, // extern functions do not support slice types.

            };
        }

        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        return function_index;
    }

    fn addCommonFnAttributes(
        o: *Object,
        attributes: *Builder.FunctionAttributes.Wip,
        owner_mod: *Package.Module,
    ) Allocator.Error!void {
        const comp = o.module.comp;

        if (!owner_mod.red_zone) {
            try attributes.addFnAttr(.noredzone, &o.builder);
        }
        if (owner_mod.omit_frame_pointer) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("frame-pointer"),
                .value = try o.builder.string("none"),
            } }, &o.builder);
        } else {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("frame-pointer"),
                .value = try o.builder.string("all"),
            } }, &o.builder);
        }
        try attributes.addFnAttr(.nounwind, &o.builder);
        if (owner_mod.unwind_tables) {
            try attributes.addFnAttr(.{ .uwtable = Builder.Attribute.UwTable.default }, &o.builder);
        }
        if (comp.skip_linker_dependencies or comp.no_builtin) {
            // The intent here is for compiler-rt and libc functions to not generate
            // infinite recursion. For example, if we are compiling the memcpy function,
            // and llvm detects that the body is equivalent to memcpy, it may replace the
            // body of memcpy with a call to memcpy, which would then cause a stack
            // overflow instead of performing memcpy.
            try attributes.addFnAttr(.nobuiltin, &o.builder);
        }
        if (owner_mod.optimize_mode == .ReleaseSmall) {
            try attributes.addFnAttr(.minsize, &o.builder);
            try attributes.addFnAttr(.optsize, &o.builder);
        }
        if (owner_mod.sanitize_thread) {
            try attributes.addFnAttr(.sanitize_thread, &o.builder);
        }
        const target = owner_mod.resolved_target.result;
        if (target.cpu.model.llvm_name) |s| {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("target-cpu"),
                .value = try o.builder.string(s),
            } }, &o.builder);
        }
        if (owner_mod.resolved_target.llvm_cpu_features) |s| {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("target-features"),
                .value = try o.builder.string(std.mem.span(s)),
            } }, &o.builder);
        }
        if (target.cpu.arch.isBpf()) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("no-builtins"),
                .value = .empty,
            } }, &o.builder);
        }
    }

    fn resolveGlobalAnonDecl(
        o: *Object,
        decl_val: InternPool.Index,
        llvm_addr_space: Builder.AddrSpace,
        alignment: InternPool.Alignment,
    ) Error!Builder.Variable.Index {
        assert(alignment != .none);
        // TODO: Add address space to the anon_decl_map
        const gop = try o.anon_decl_map.getOrPut(o.gpa, decl_val);
        if (gop.found_existing) {
            // Keep the greater of the two alignments.
            const variable_index = gop.value_ptr.ptr(&o.builder).kind.variable;
            const old_alignment = InternPool.Alignment.fromLlvm(variable_index.getAlignment(&o.builder));
            const max_alignment = old_alignment.maxStrict(alignment);
            variable_index.setAlignment(max_alignment.toLlvm(), &o.builder);
            return variable_index;
        }
        errdefer assert(o.anon_decl_map.remove(decl_val));

        const mod = o.module;
        const decl_ty = mod.intern_pool.typeOf(decl_val);

        const variable_index = try o.builder.addVariable(
            try o.builder.fmt("__anon_{d}", .{@intFromEnum(decl_val)}),
            try o.lowerType(Type.fromInterned(decl_ty)),
            llvm_addr_space,
        );
        gop.value_ptr.* = variable_index.ptrConst(&o.builder).global;

        try variable_index.setInitializer(try o.lowerValue(decl_val), &o.builder);
        variable_index.setLinkage(.internal, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(alignment.toLlvm(), &o.builder);
        return variable_index;
    }

    fn resolveGlobalDecl(
        o: *Object,
        decl_index: InternPool.DeclIndex,
    ) Allocator.Error!Builder.Variable.Index {
        const gop = try o.decl_map.getOrPut(o.gpa, decl_index);
        if (gop.found_existing) return gop.value_ptr.ptr(&o.builder).kind.variable;
        errdefer assert(o.decl_map.remove(decl_index));

        const mod = o.module;
        const decl = mod.declPtr(decl_index);
        const is_extern = decl.isExtern(mod);

        const variable_index = try o.builder.addVariable(
            try o.builder.string(mod.intern_pool.stringToSlice(
                if (is_extern) decl.name else try decl.getFullyQualifiedName(mod),
            )),
            try o.lowerType(decl.ty),
            toLlvmGlobalAddressSpace(decl.@"addrspace", mod.getTarget()),
        );
        gop.value_ptr.* = variable_index.ptrConst(&o.builder).global;

        // This is needed for declarations created by `@extern`.
        if (is_extern) {
            variable_index.setLinkage(.external, &o.builder);
            variable_index.setUnnamedAddr(.default, &o.builder);
            if (decl.val.getVariable(mod)) |decl_var| {
                const decl_namespace = mod.namespacePtr(decl.src_namespace);
                const single_threaded = decl_namespace.file_scope.mod.single_threaded;
                variable_index.setThreadLocal(
                    if (decl_var.is_threadlocal and !single_threaded) .generaldynamic else .default,
                    &o.builder,
                );
                if (decl_var.is_weak_linkage) variable_index.setLinkage(.extern_weak, &o.builder);
            }
        } else {
            variable_index.setLinkage(.internal, &o.builder);
            variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        }
        return variable_index;
    }

    fn errorIntType(o: *Object) Allocator.Error!Builder.Type {
        return o.builder.intType(o.module.errorSetBits());
    }

    fn lowerType(o: *Object, t: Type) Allocator.Error!Builder.Type {
        const ty = try o.lowerTypeInner(t);
        const mod = o.module;
        if (std.debug.runtime_safety and o.builder.useLibLlvm() and false) check: {
            const llvm_ty = ty.toLlvm(&o.builder);
            if (t.zigTypeTag(mod) == .Opaque) break :check;
            if (!t.hasRuntimeBits(mod)) break :check;
            if (!try ty.isSized(&o.builder)) break :check;

            const zig_size = t.abiSize(mod);
            const llvm_size = o.target_data.abiSizeOfType(llvm_ty);
            if (llvm_size != zig_size) {
                log.err("when lowering {}, Zig ABI size = {d} but LLVM ABI size = {d}", .{
                    t.fmt(o.module), zig_size, llvm_size,
                });
            }
        }
        return ty;
    }

    fn lowerTypeInner(o: *Object, t: Type) Allocator.Error!Builder.Type {
        const mod = o.module;
        const target = mod.getTarget();
        const ip = &mod.intern_pool;
        return switch (t.toIntern()) {
            .u0_type, .i0_type => unreachable,
            inline .u1_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u29_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .u80_type,
            .u128_type,
            .i128_type,
            => |tag| @field(Builder.Type, "i" ++ @tagName(tag)[1 .. @tagName(tag).len - "_type".len]),
            .usize_type, .isize_type => try o.builder.intType(target.ptrBitWidth()),
            inline .c_char_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            => |tag| try o.builder.intType(target.c_type_bit_size(
                @field(std.Target.CType, @tagName(tag)["c_".len .. @tagName(tag).len - "_type".len]),
            )),
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f80_type,
            .f128_type,
            => switch (t.floatBits(target)) {
                16 => if (backendSupportsF16(target)) .half else .i16,
                32 => .float,
                64 => .double,
                80 => if (backendSupportsF80(target)) .x86_fp80 else .i80,
                128 => .fp128,
                else => unreachable,
            },
            .anyopaque_type => unreachable,
            .bool_type => .i1,
            .void_type => .void,
            .type_type => unreachable,
            .anyerror_type => try o.errorIntType(),
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            => unreachable,
            .anyframe_type => @panic("TODO implement lowerType for AnyFrame types"),
            .null_type,
            .undefined_type,
            .enum_literal_type,
            => unreachable,
            .manyptr_u8_type,
            .manyptr_const_u8_type,
            .manyptr_const_u8_sentinel_0_type,
            .single_const_pointer_to_comptime_int_type,
            => .ptr,
            .slice_const_u8_type,
            .slice_const_u8_sentinel_0_type,
            => try o.builder.structType(.normal, &.{ .ptr, try o.lowerType(Type.usize) }),
            .optional_noreturn_type => unreachable,
            .anyerror_void_error_union_type,
            .adhoc_inferred_error_set_type,
            => try o.errorIntType(),
            .generic_poison_type,
            .empty_struct_type,
            => unreachable,
            // values, not types
            .undef,
            .zero,
            .zero_usize,
            .zero_u8,
            .one,
            .one_usize,
            .one_u8,
            .four_u8,
            .negative_one,
            .calling_convention_c,
            .calling_convention_inline,
            .void_value,
            .unreachable_value,
            .null_value,
            .bool_true,
            .bool_false,
            .empty_struct,
            .generic_poison,
            .var_args_param_type,
            .none,
            => unreachable,
            else => switch (ip.indexToKey(t.toIntern())) {
                .int_type => |int_type| try o.builder.intType(int_type.bits),
                .ptr_type => |ptr_type| type: {
                    const ptr_ty = try o.builder.ptrType(
                        toLlvmAddressSpace(ptr_type.flags.address_space, target),
                    );
                    break :type switch (ptr_type.flags.size) {
                        .One, .Many, .C => ptr_ty,
                        .Slice => try o.builder.structType(.normal, &.{
                            ptr_ty,
                            try o.lowerType(Type.usize),
                        }),
                    };
                },
                .array_type => |array_type| o.builder.arrayType(
                    array_type.len + @intFromBool(array_type.sentinel != .none),
                    try o.lowerType(Type.fromInterned(array_type.child)),
                ),
                .vector_type => |vector_type| o.builder.vectorType(
                    .normal,
                    vector_type.len,
                    try o.lowerType(Type.fromInterned(vector_type.child)),
                ),
                .opt_type => |child_ty| {
                    if (!Type.fromInterned(child_ty).hasRuntimeBitsIgnoreComptime(mod)) return .i8;

                    const payload_ty = try o.lowerType(Type.fromInterned(child_ty));
                    if (t.optionalReprIsPayload(mod)) return payload_ty;

                    comptime assert(optional_layout_version == 3);
                    var fields: [3]Builder.Type = .{ payload_ty, .i8, undefined };
                    var fields_len: usize = 2;
                    const offset = Type.fromInterned(child_ty).abiSize(mod) + 1;
                    const abi_size = t.abiSize(mod);
                    const padding_len = abi_size - offset;
                    if (padding_len > 0) {
                        fields[2] = try o.builder.arrayType(padding_len, .i8);
                        fields_len = 3;
                    }
                    return o.builder.structType(.normal, fields[0..fields_len]);
                },
                .anyframe_type => @panic("TODO implement lowerType for AnyFrame types"),
                .error_union_type => |error_union_type| {
                    const error_type = try o.errorIntType();
                    if (!Type.fromInterned(error_union_type.payload_type).hasRuntimeBitsIgnoreComptime(mod))
                        return error_type;
                    const payload_type = try o.lowerType(Type.fromInterned(error_union_type.payload_type));
                    const err_int_ty = try mod.errorIntType();

                    const payload_align = Type.fromInterned(error_union_type.payload_type).abiAlignment(mod);
                    const error_align = err_int_ty.abiAlignment(mod);

                    const payload_size = Type.fromInterned(error_union_type.payload_type).abiSize(mod);
                    const error_size = err_int_ty.abiSize(mod);

                    var fields: [3]Builder.Type = undefined;
                    var fields_len: usize = 2;
                    const padding_len = if (error_align.compare(.gt, payload_align)) pad: {
                        fields[0] = error_type;
                        fields[1] = payload_type;
                        const payload_end =
                            payload_align.forward(error_size) +
                            payload_size;
                        const abi_size = error_align.forward(payload_end);
                        break :pad abi_size - payload_end;
                    } else pad: {
                        fields[0] = payload_type;
                        fields[1] = error_type;
                        const error_end =
                            error_align.forward(payload_size) +
                            error_size;
                        const abi_size = payload_align.forward(error_end);
                        break :pad abi_size - error_end;
                    };
                    if (padding_len > 0) {
                        fields[2] = try o.builder.arrayType(padding_len, .i8);
                        fields_len = 3;
                    }
                    return o.builder.structType(.normal, fields[0..fields_len]);
                },
                .simple_type => unreachable,
                .struct_type => |struct_type| {
                    const gop = try o.type_map.getOrPut(o.gpa, t.toIntern());
                    if (gop.found_existing) return gop.value_ptr.*;

                    if (struct_type.layout == .Packed) {
                        const int_ty = try o.lowerType(Type.fromInterned(struct_type.backingIntType(ip).*));
                        gop.value_ptr.* = int_ty;
                        return int_ty;
                    }

                    const name = try o.builder.string(ip.stringToSlice(
                        try mod.declPtr(struct_type.decl.unwrap().?).getFullyQualifiedName(mod),
                    ));
                    const ty = try o.builder.opaqueType(name);
                    gop.value_ptr.* = ty; // must be done before any recursive calls

                    var llvm_field_types = std.ArrayListUnmanaged(Builder.Type){};
                    defer llvm_field_types.deinit(o.gpa);
                    // Although we can estimate how much capacity to add, these cannot be
                    // relied upon because of the recursive calls to lowerType below.
                    try llvm_field_types.ensureUnusedCapacity(o.gpa, struct_type.field_types.len);
                    try o.struct_field_map.ensureUnusedCapacity(o.gpa, struct_type.field_types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .@"1";
                    var struct_kind: Builder.Type.Structure.Kind = .normal;
                    // When we encounter a zero-bit field, we place it here so we know to map it to the next non-zero-bit field (if any).
                    var it = struct_type.iterateRuntimeOrder(ip);
                    while (it.next()) |field_index| {
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                        const field_align = mod.structFieldAlignment(
                            struct_type.fieldAlign(ip, field_index),
                            field_ty,
                            struct_type.layout,
                        );
                        const field_ty_align = field_ty.abiAlignment(mod);
                        if (field_align.compare(.lt, field_ty_align)) struct_kind = .@"packed";
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );

                        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                            // This is a zero-bit field. If there are runtime bits after this field,
                            // map to the next LLVM field (which we know exists): otherwise, don't
                            // map the field, indicating it's at the end of the struct.
                            if (offset != struct_type.size(ip).*) {
                                try o.struct_field_map.put(o.gpa, .{
                                    .struct_ty = t.toIntern(),
                                    .field_index = field_index,
                                }, @intCast(llvm_field_types.items.len));
                            }
                            continue;
                        }

                        try o.struct_field_map.put(o.gpa, .{
                            .struct_ty = t.toIntern(),
                            .field_index = field_index,
                        }, @intCast(llvm_field_types.items.len));
                        try llvm_field_types.append(o.gpa, try o.lowerType(field_ty));

                        offset += field_ty.abiSize(mod);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                    }

                    try o.builder.namedTypeSetBody(
                        ty,
                        try o.builder.structType(struct_kind, llvm_field_types.items),
                    );
                    return ty;
                },
                .anon_struct_type => |anon_struct_type| {
                    var llvm_field_types: std.ArrayListUnmanaged(Builder.Type) = .{};
                    defer llvm_field_types.deinit(o.gpa);
                    // Although we can estimate how much capacity to add, these cannot be
                    // relied upon because of the recursive calls to lowerType below.
                    try llvm_field_types.ensureUnusedCapacity(o.gpa, anon_struct_type.types.len);
                    try o.struct_field_map.ensureUnusedCapacity(o.gpa, anon_struct_type.types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .none;

                    const struct_size = t.abiSize(mod);

                    for (
                        anon_struct_type.types.get(ip),
                        anon_struct_type.values.get(ip),
                        0..,
                    ) |field_ty, field_val, field_index| {
                        if (field_val != .none) continue;

                        const field_align = Type.fromInterned(field_ty).abiAlignment(mod);
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) {
                            // This is a zero-bit field. If there are runtime bits after this field,
                            // map to the next LLVM field (which we know exists): otherwise, don't
                            // map the field, indicating it's at the end of the struct.
                            if (offset != struct_size) {
                                try o.struct_field_map.put(o.gpa, .{
                                    .struct_ty = t.toIntern(),
                                    .field_index = @intCast(field_index),
                                }, @intCast(llvm_field_types.items.len));
                            }
                            continue;
                        }
                        try o.struct_field_map.put(o.gpa, .{
                            .struct_ty = t.toIntern(),
                            .field_index = @intCast(field_index),
                        }, @intCast(llvm_field_types.items.len));
                        try llvm_field_types.append(o.gpa, try o.lowerType(Type.fromInterned(field_ty)));

                        offset += Type.fromInterned(field_ty).abiSize(mod);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                    }
                    return o.builder.structType(.normal, llvm_field_types.items);
                },
                .union_type => |union_type| {
                    const gop = try o.type_map.getOrPut(o.gpa, t.toIntern());
                    if (gop.found_existing) return gop.value_ptr.*;

                    const union_obj = ip.loadUnionType(union_type);
                    const layout = mod.getUnionLayout(union_obj);

                    if (union_obj.flagsPtr(ip).layout == .Packed) {
                        const int_ty = try o.builder.intType(@intCast(t.bitSize(mod)));
                        gop.value_ptr.* = int_ty;
                        return int_ty;
                    }

                    if (layout.payload_size == 0) {
                        const enum_tag_ty = try o.lowerType(Type.fromInterned(union_obj.enum_tag_ty));
                        gop.value_ptr.* = enum_tag_ty;
                        return enum_tag_ty;
                    }

                    const name = try o.builder.string(ip.stringToSlice(
                        try mod.declPtr(union_obj.decl).getFullyQualifiedName(mod),
                    ));
                    const ty = try o.builder.opaqueType(name);
                    gop.value_ptr.* = ty; // must be done before any recursive calls

                    const aligned_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[layout.most_aligned_field]);
                    const aligned_field_llvm_ty = try o.lowerType(aligned_field_ty);

                    const payload_ty = ty: {
                        if (layout.most_aligned_field_size == layout.payload_size) {
                            break :ty aligned_field_llvm_ty;
                        }
                        const padding_len = if (layout.tag_size == 0)
                            layout.abi_size - layout.most_aligned_field_size
                        else
                            layout.payload_size - layout.most_aligned_field_size;
                        break :ty try o.builder.structType(.@"packed", &.{
                            aligned_field_llvm_ty,
                            try o.builder.arrayType(padding_len, .i8),
                        });
                    };

                    if (layout.tag_size == 0) {
                        try o.builder.namedTypeSetBody(
                            ty,
                            try o.builder.structType(.normal, &.{payload_ty}),
                        );
                        return ty;
                    }
                    const enum_tag_ty = try o.lowerType(Type.fromInterned(union_obj.enum_tag_ty));

                    // Put the tag before or after the payload depending on which one's
                    // alignment is greater.
                    var llvm_fields: [3]Builder.Type = undefined;
                    var llvm_fields_len: usize = 2;

                    if (layout.tag_align.compare(.gte, layout.payload_align)) {
                        llvm_fields = .{ enum_tag_ty, payload_ty, .none };
                    } else {
                        llvm_fields = .{ payload_ty, enum_tag_ty, .none };
                    }

                    // Insert padding to make the LLVM struct ABI size match the Zig union ABI size.
                    if (layout.padding != 0) {
                        llvm_fields[llvm_fields_len] = try o.builder.arrayType(layout.padding, .i8);
                        llvm_fields_len += 1;
                    }

                    try o.builder.namedTypeSetBody(
                        ty,
                        try o.builder.structType(.normal, llvm_fields[0..llvm_fields_len]),
                    );
                    return ty;
                },
                .opaque_type => |opaque_type| {
                    const gop = try o.type_map.getOrPut(o.gpa, t.toIntern());
                    if (!gop.found_existing) {
                        const name = try o.builder.string(ip.stringToSlice(
                            try mod.opaqueFullyQualifiedName(opaque_type),
                        ));
                        gop.value_ptr.* = try o.builder.opaqueType(name);
                    }
                    return gop.value_ptr.*;
                },
                .enum_type => |enum_type| try o.lowerType(Type.fromInterned(enum_type.tag_ty)),
                .func_type => |func_type| try o.lowerTypeFn(func_type),
                .error_set_type, .inferred_error_set_type => try o.errorIntType(),
                // values, not types
                .undef,
                .simple_value,
                .variable,
                .extern_func,
                .func,
                .int,
                .err,
                .error_union,
                .enum_literal,
                .enum_tag,
                .empty_enum_value,
                .float,
                .ptr,
                .opt,
                .aggregate,
                .un,
                // memoization, not types
                .memoized_call,
                => unreachable,
            },
        };
    }

    /// Use this instead of lowerType when you want to handle correctly the case of elem_ty
    /// being a zero bit type, but it should still be lowered as an i8 in such case.
    /// There are other similar cases handled here as well.
    fn lowerPtrElemTy(o: *Object, elem_ty: Type) Allocator.Error!Builder.Type {
        const mod = o.module;
        const lower_elem_ty = switch (elem_ty.zigTypeTag(mod)) {
            .Opaque => true,
            .Fn => !mod.typeToFunc(elem_ty).?.is_generic,
            .Array => elem_ty.childType(mod).hasRuntimeBitsIgnoreComptime(mod),
            else => elem_ty.hasRuntimeBitsIgnoreComptime(mod),
        };
        return if (lower_elem_ty) try o.lowerType(elem_ty) else .i8;
    }

    fn lowerTypeFn(o: *Object, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
        const mod = o.module;
        const ip = &mod.intern_pool;
        const target = mod.getTarget();
        const ret_ty = try lowerFnRetTy(o, fn_info);

        var llvm_params = std.ArrayListUnmanaged(Builder.Type){};
        defer llvm_params.deinit(o.gpa);

        if (firstParamSRet(fn_info, mod)) {
            try llvm_params.append(o.gpa, .ptr);
        }

        if (Type.fromInterned(fn_info.return_type).isError(mod) and
            mod.comp.config.any_error_tracing)
        {
            const ptr_ty = try mod.singleMutPtrType(try o.getStackTraceType());
            try llvm_params.append(o.gpa, try o.lowerType(ptr_ty));
        }

        var it = iterateParamTypes(o, fn_info);
        while (try it.next()) |lowering| switch (lowering) {
            .no_bits => continue,
            .byval => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.append(o.gpa, try o.lowerType(param_ty));
            },
            .byref, .byref_mut => {
                try llvm_params.append(o.gpa, .ptr);
            },
            .abi_sized_int => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.append(o.gpa, try o.builder.intType(
                    @intCast(param_ty.abiSize(mod) * 8),
                ));
            },
            .slice => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.appendSlice(o.gpa, &.{
                    try o.builder.ptrType(toLlvmAddressSpace(param_ty.ptrAddressSpace(mod), target)),
                    try o.lowerType(Type.usize),
                });
            },
            .multiple_llvm_types => {
                try llvm_params.appendSlice(o.gpa, it.types_buffer[0..it.types_len]);
            },
            .as_u16 => {
                try llvm_params.append(o.gpa, .i16);
            },
            .float_array => |count| {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                const float_ty = try o.lowerType(aarch64_c_abi.getFloatArrayType(param_ty, mod).?);
                try llvm_params.append(o.gpa, try o.builder.arrayType(count, float_ty));
            },
            .i32_array, .i64_array => |arr_len| {
                try llvm_params.append(o.gpa, try o.builder.arrayType(arr_len, switch (lowering) {
                    .i32_array => .i32,
                    .i64_array => .i64,
                    else => unreachable,
                }));
            },
        };

        return o.builder.fnType(
            ret_ty,
            llvm_params.items,
            if (fn_info.is_var_args) .vararg else .normal,
        );
    }

    fn lowerValue(o: *Object, arg_val: InternPool.Index) Error!Builder.Constant {
        const mod = o.module;
        const ip = &mod.intern_pool;
        const target = mod.getTarget();

        const val = Value.fromInterned(arg_val);
        const val_key = ip.indexToKey(val.toIntern());

        if (val.isUndefDeep(mod)) {
            return o.builder.undefConst(try o.lowerType(Type.fromInterned(val_key.typeOf())));
        }

        const ty = Type.fromInterned(val_key.typeOf());
        return switch (val_key) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .anon_struct_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            => unreachable, // types, not values

            .undef => unreachable, // handled above
            .simple_value => |simple_value| switch (simple_value) {
                .undefined,
                .void,
                .null,
                .empty_struct,
                .@"unreachable",
                .generic_poison,
                => unreachable, // non-runtime values
                .false => .false,
                .true => .true,
            },
            .variable,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values
            .extern_func => |extern_func| {
                const fn_decl_index = extern_func.decl;
                const fn_decl = mod.declPtr(fn_decl_index);
                try mod.markDeclAlive(fn_decl);
                const function_index = try o.resolveLlvmFunction(fn_decl_index);
                return function_index.ptrConst(&o.builder).global.toConst();
            },
            .func => |func| {
                const fn_decl_index = func.owner_decl;
                const fn_decl = mod.declPtr(fn_decl_index);
                try mod.markDeclAlive(fn_decl);
                const function_index = try o.resolveLlvmFunction(fn_decl_index);
                return function_index.ptrConst(&o.builder).global.toConst();
            },
            .int => {
                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = val.toBigInt(&bigint_space, mod);
                return lowerBigInt(o, ty, bigint);
            },
            .err => |err| {
                const int = try mod.getErrorValue(err.name);
                const llvm_int = try o.builder.intConst(try o.errorIntType(), int);
                return llvm_int;
            },
            .error_union => |error_union| {
                const err_val = switch (error_union.val) {
                    .err_name => |err_name| try mod.intern(.{ .err = .{
                        .ty = ty.errorUnionSet(mod).toIntern(),
                        .name = err_name,
                    } }),
                    .payload => (try mod.intValue(try mod.errorIntType(), 0)).toIntern(),
                };
                const err_int_ty = try mod.errorIntType();
                const payload_type = ty.errorUnionPayload(mod);
                if (!payload_type.hasRuntimeBitsIgnoreComptime(mod)) {
                    // We use the error type directly as the type.
                    return o.lowerValue(err_val);
                }

                const payload_align = payload_type.abiAlignment(mod);
                const error_align = err_int_ty.abiAlignment(mod);
                const llvm_error_value = try o.lowerValue(err_val);
                const llvm_payload_value = try o.lowerValue(switch (error_union.val) {
                    .err_name => try mod.intern(.{ .undef = payload_type.toIntern() }),
                    .payload => |payload| payload,
                });

                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                if (error_align.compare(.gt, payload_align)) {
                    vals[0] = llvm_error_value;
                    vals[1] = llvm_payload_value;
                } else {
                    vals[0] = llvm_payload_value;
                    vals[1] = llvm_error_value;
                }
                fields[0] = vals[0].typeOf(&o.builder);
                fields[1] = vals[1].typeOf(&o.builder);

                const llvm_ty = try o.lowerType(ty);
                const llvm_ty_fields = llvm_ty.structFields(&o.builder);
                if (llvm_ty_fields.len > 2) {
                    assert(llvm_ty_fields.len == 3);
                    fields[2] = llvm_ty_fields[2];
                    vals[2] = try o.builder.undefConst(fields[2]);
                }
                return o.builder.structConst(try o.builder.structType(
                    llvm_ty.structKind(&o.builder),
                    fields[0..llvm_ty_fields.len],
                ), vals[0..llvm_ty_fields.len]);
            },
            .enum_tag => |enum_tag| o.lowerValue(enum_tag.int),
            .float => switch (ty.floatBits(target)) {
                16 => if (backendSupportsF16(target))
                    try o.builder.halfConst(val.toFloat(f16, mod))
                else
                    try o.builder.intConst(.i16, @as(i16, @bitCast(val.toFloat(f16, mod)))),
                32 => try o.builder.floatConst(val.toFloat(f32, mod)),
                64 => try o.builder.doubleConst(val.toFloat(f64, mod)),
                80 => if (backendSupportsF80(target))
                    try o.builder.x86_fp80Const(val.toFloat(f80, mod))
                else
                    try o.builder.intConst(.i80, @as(i80, @bitCast(val.toFloat(f80, mod)))),
                128 => try o.builder.fp128Const(val.toFloat(f128, mod)),
                else => unreachable,
            },
            .ptr => |ptr| {
                const ptr_ty = switch (ptr.len) {
                    .none => ty,
                    else => ty.slicePtrFieldType(mod),
                };
                const ptr_val = switch (ptr.addr) {
                    .decl => |decl| try o.lowerDeclRefValue(ptr_ty, decl),
                    .mut_decl => |mut_decl| try o.lowerDeclRefValue(ptr_ty, mut_decl.decl),
                    .anon_decl => |anon_decl| try o.lowerAnonDeclRef(ptr_ty, anon_decl),
                    .int => |int| try o.lowerIntAsPtr(int),
                    .eu_payload,
                    .opt_payload,
                    .elem,
                    .field,
                    => try o.lowerParentPtr(val),
                    .comptime_field => unreachable,
                };
                switch (ptr.len) {
                    .none => return ptr_val,
                    else => return o.builder.structConst(try o.lowerType(ty), &.{
                        ptr_val, try o.lowerValue(ptr.len),
                    }),
                }
            },
            .opt => |opt| {
                comptime assert(optional_layout_version == 3);
                const payload_ty = ty.optionalChild(mod);

                const non_null_bit = try o.builder.intConst(.i8, @intFromBool(opt.val != .none));
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    return non_null_bit;
                }
                const llvm_ty = try o.lowerType(ty);
                if (ty.optionalReprIsPayload(mod)) return switch (opt.val) {
                    .none => switch (llvm_ty.tag(&o.builder)) {
                        .integer => try o.builder.intConst(llvm_ty, 0),
                        .pointer => try o.builder.nullConst(llvm_ty),
                        .structure => try o.builder.zeroInitConst(llvm_ty),
                        else => unreachable,
                    },
                    else => |payload| try o.lowerValue(payload),
                };
                assert(payload_ty.zigTypeTag(mod) != .Fn);

                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                vals[0] = try o.lowerValue(switch (opt.val) {
                    .none => try mod.intern(.{ .undef = payload_ty.toIntern() }),
                    else => |payload| payload,
                });
                vals[1] = non_null_bit;
                fields[0] = vals[0].typeOf(&o.builder);
                fields[1] = vals[1].typeOf(&o.builder);

                const llvm_ty_fields = llvm_ty.structFields(&o.builder);
                if (llvm_ty_fields.len > 2) {
                    assert(llvm_ty_fields.len == 3);
                    fields[2] = llvm_ty_fields[2];
                    vals[2] = try o.builder.undefConst(fields[2]);
                }
                return o.builder.structConst(try o.builder.structType(
                    llvm_ty.structKind(&o.builder),
                    fields[0..llvm_ty_fields.len],
                ), vals[0..llvm_ty_fields.len]);
            },
            .aggregate => |aggregate| switch (ip.indexToKey(ty.toIntern())) {
                .array_type => |array_type| switch (aggregate.storage) {
                    .bytes => |bytes| try o.builder.stringConst(try o.builder.string(bytes)),
                    .elems => |elems| {
                        const array_ty = try o.lowerType(ty);
                        const elem_ty = array_ty.childType(&o.builder);
                        assert(elems.len == array_ty.aggregateLen(&o.builder));

                        const ExpectedContents = extern struct {
                            vals: [Builder.expected_fields_len]Builder.Constant,
                            fields: [Builder.expected_fields_len]Builder.Type,
                        };
                        var stack align(@max(
                            @alignOf(std.heap.StackFallbackAllocator(0)),
                            @alignOf(ExpectedContents),
                        )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                        const allocator = stack.get();
                        const vals = try allocator.alloc(Builder.Constant, elems.len);
                        defer allocator.free(vals);
                        const fields = try allocator.alloc(Builder.Type, elems.len);
                        defer allocator.free(fields);

                        var need_unnamed = false;
                        for (vals, fields, elems) |*result_val, *result_field, elem| {
                            result_val.* = try o.lowerValue(elem);
                            result_field.* = result_val.typeOf(&o.builder);
                            if (result_field.* != elem_ty) need_unnamed = true;
                        }
                        return if (need_unnamed) try o.builder.structConst(
                            try o.builder.structType(.normal, fields),
                            vals,
                        ) else try o.builder.arrayConst(array_ty, vals);
                    },
                    .repeated_elem => |elem| {
                        const len: usize = @intCast(array_type.len);
                        const len_including_sentinel: usize =
                            @intCast(len + @intFromBool(array_type.sentinel != .none));
                        const array_ty = try o.lowerType(ty);
                        const elem_ty = array_ty.childType(&o.builder);

                        const ExpectedContents = extern struct {
                            vals: [Builder.expected_fields_len]Builder.Constant,
                            fields: [Builder.expected_fields_len]Builder.Type,
                        };
                        var stack align(@max(
                            @alignOf(std.heap.StackFallbackAllocator(0)),
                            @alignOf(ExpectedContents),
                        )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                        const allocator = stack.get();
                        const vals = try allocator.alloc(Builder.Constant, len_including_sentinel);
                        defer allocator.free(vals);
                        const fields = try allocator.alloc(Builder.Type, len_including_sentinel);
                        defer allocator.free(fields);

                        var need_unnamed = false;
                        @memset(vals[0..len], try o.lowerValue(elem));
                        @memset(fields[0..len], vals[0].typeOf(&o.builder));
                        if (fields[0] != elem_ty) need_unnamed = true;

                        if (array_type.sentinel != .none) {
                            vals[len] = try o.lowerValue(array_type.sentinel);
                            fields[len] = vals[len].typeOf(&o.builder);
                            if (fields[len] != elem_ty) need_unnamed = true;
                        }

                        return if (need_unnamed) try o.builder.structConst(
                            try o.builder.structType(.@"packed", fields),
                            vals,
                        ) else try o.builder.arrayConst(array_ty, vals);
                    },
                },
                .vector_type => |vector_type| {
                    const vector_ty = try o.lowerType(ty);
                    switch (aggregate.storage) {
                        .bytes, .elems => {
                            const ExpectedContents = [Builder.expected_fields_len]Builder.Constant;
                            var stack align(@max(
                                @alignOf(std.heap.StackFallbackAllocator(0)),
                                @alignOf(ExpectedContents),
                            )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                            const allocator = stack.get();
                            const vals = try allocator.alloc(Builder.Constant, vector_type.len);
                            defer allocator.free(vals);

                            switch (aggregate.storage) {
                                .bytes => |bytes| for (vals, bytes) |*result_val, byte| {
                                    result_val.* = try o.builder.intConst(.i8, byte);
                                },
                                .elems => |elems| for (vals, elems) |*result_val, elem| {
                                    result_val.* = try o.lowerValue(elem);
                                },
                                .repeated_elem => unreachable,
                            }
                            return o.builder.vectorConst(vector_ty, vals);
                        },
                        .repeated_elem => |elem| return o.builder.splatConst(
                            vector_ty,
                            try o.lowerValue(elem),
                        ),
                    }
                },
                .anon_struct_type => |tuple| {
                    const struct_ty = try o.lowerType(ty);
                    const llvm_len = struct_ty.aggregateLen(&o.builder);

                    const ExpectedContents = extern struct {
                        vals: [Builder.expected_fields_len]Builder.Constant,
                        fields: [Builder.expected_fields_len]Builder.Type,
                    };
                    var stack align(@max(
                        @alignOf(std.heap.StackFallbackAllocator(0)),
                        @alignOf(ExpectedContents),
                    )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                    const allocator = stack.get();
                    const vals = try allocator.alloc(Builder.Constant, llvm_len);
                    defer allocator.free(vals);
                    const fields = try allocator.alloc(Builder.Type, llvm_len);
                    defer allocator.free(fields);

                    comptime assert(struct_layout_version == 2);
                    var llvm_index: usize = 0;
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .none;
                    var need_unnamed = false;
                    for (
                        tuple.types.get(ip),
                        tuple.values.get(ip),
                        0..,
                    ) |field_ty, field_val, field_index| {
                        if (field_val != .none) continue;
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) continue;

                        const field_align = Type.fromInterned(field_ty).abiAlignment(mod);
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            // TODO make this and all other padding elsewhere in debug
                            // builds be 0xaa not undef.
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }

                        vals[llvm_index] =
                            try o.lowerValue((try val.fieldValue(mod, field_index)).toIntern());
                        fields[llvm_index] = vals[llvm_index].typeOf(&o.builder);
                        if (fields[llvm_index] != struct_ty.structFields(&o.builder)[llvm_index])
                            need_unnamed = true;
                        llvm_index += 1;

                        offset += Type.fromInterned(field_ty).abiSize(mod);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }
                    }
                    assert(llvm_index == llvm_len);

                    return o.builder.structConst(if (need_unnamed)
                        try o.builder.structType(struct_ty.structKind(&o.builder), fields)
                    else
                        struct_ty, vals);
                },
                .struct_type => |struct_type| {
                    assert(struct_type.haveLayout(ip));
                    const struct_ty = try o.lowerType(ty);
                    if (struct_type.layout == .Packed) {
                        comptime assert(Type.packed_struct_layout_version == 2);
                        var running_int = try o.builder.intConst(struct_ty, 0);
                        var running_bits: u16 = 0;
                        for (struct_type.field_types.get(ip), 0..) |field_ty, field_index| {
                            if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) continue;

                            const non_int_val =
                                try o.lowerValue((try val.fieldValue(mod, field_index)).toIntern());
                            const ty_bit_size: u16 = @intCast(Type.fromInterned(field_ty).bitSize(mod));
                            const small_int_ty = try o.builder.intType(ty_bit_size);
                            const small_int_val = try o.builder.castConst(
                                if (Type.fromInterned(field_ty).isPtrAtRuntime(mod)) .ptrtoint else .bitcast,
                                non_int_val,
                                small_int_ty,
                            );
                            const shift_rhs = try o.builder.intConst(struct_ty, running_bits);
                            const extended_int_val =
                                try o.builder.convConst(.unsigned, small_int_val, struct_ty);
                            const shifted = try o.builder.binConst(.shl, extended_int_val, shift_rhs);
                            running_int = try o.builder.binConst(.@"or", running_int, shifted);
                            running_bits += ty_bit_size;
                        }
                        return running_int;
                    }
                    const llvm_len = struct_ty.aggregateLen(&o.builder);

                    const ExpectedContents = extern struct {
                        vals: [Builder.expected_fields_len]Builder.Constant,
                        fields: [Builder.expected_fields_len]Builder.Type,
                    };
                    var stack align(@max(
                        @alignOf(std.heap.StackFallbackAllocator(0)),
                        @alignOf(ExpectedContents),
                    )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                    const allocator = stack.get();
                    const vals = try allocator.alloc(Builder.Constant, llvm_len);
                    defer allocator.free(vals);
                    const fields = try allocator.alloc(Builder.Type, llvm_len);
                    defer allocator.free(fields);

                    comptime assert(struct_layout_version == 2);
                    var llvm_index: usize = 0;
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .@"1";
                    var need_unnamed = false;
                    var field_it = struct_type.iterateRuntimeOrder(ip);
                    while (field_it.next()) |field_index| {
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                        const field_align = mod.structFieldAlignment(
                            struct_type.fieldAlign(ip, field_index),
                            field_ty,
                            struct_type.layout,
                        );
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            // TODO make this and all other padding elsewhere in debug
                            // builds be 0xaa not undef.
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] ==
                                struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }

                        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                            // This is a zero-bit field - we only needed it for the alignment.
                            continue;
                        }

                        vals[llvm_index] = try o.lowerValue(
                            (try val.fieldValue(mod, field_index)).toIntern(),
                        );
                        fields[llvm_index] = vals[llvm_index].typeOf(&o.builder);
                        if (fields[llvm_index] != struct_ty.structFields(&o.builder)[llvm_index])
                            need_unnamed = true;
                        llvm_index += 1;

                        offset += field_ty.abiSize(mod);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }
                    }
                    assert(llvm_index == llvm_len);

                    return o.builder.structConst(if (need_unnamed)
                        try o.builder.structType(struct_ty.structKind(&o.builder), fields)
                    else
                        struct_ty, vals);
                },
                else => unreachable,
            },
            .un => |un| {
                const union_ty = try o.lowerType(ty);
                const layout = ty.unionGetLayout(mod);
                if (layout.payload_size == 0) return o.lowerValue(un.tag);

                const union_obj = mod.typeToUnion(ty).?;
                const container_layout = union_obj.getLayout(ip);

                var need_unnamed = false;
                const payload = if (un.tag != .none) p: {
                    const field_index = mod.unionTagFieldIndex(union_obj, Value.fromInterned(un.tag)).?;
                    const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                    if (container_layout == .Packed) {
                        if (!field_ty.hasRuntimeBits(mod)) return o.builder.intConst(union_ty, 0);
                        const small_int_val = try o.builder.castConst(
                            if (field_ty.isPtrAtRuntime(mod)) .ptrtoint else .bitcast,
                            try o.lowerValue(un.val),
                            try o.builder.intType(@intCast(field_ty.bitSize(mod))),
                        );
                        return o.builder.convConst(.unsigned, small_int_val, union_ty);
                    }

                    // Sometimes we must make an unnamed struct because LLVM does
                    // not support bitcasting our payload struct to the true union payload type.
                    // Instead we use an unnamed struct and every reference to the global
                    // must pointer cast to the expected type before accessing the union.
                    need_unnamed = layout.most_aligned_field != field_index;

                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        const padding_len = layout.payload_size;
                        break :p try o.builder.undefConst(try o.builder.arrayType(padding_len, .i8));
                    }
                    const payload = try o.lowerValue(un.val);
                    const payload_ty = payload.typeOf(&o.builder);
                    if (payload_ty != union_ty.structFields(&o.builder)[
                        @intFromBool(layout.tag_align.compare(.gte, layout.payload_align))
                    ]) need_unnamed = true;
                    const field_size = field_ty.abiSize(mod);
                    if (field_size == layout.payload_size) break :p payload;
                    const padding_len = layout.payload_size - field_size;
                    const padding_ty = try o.builder.arrayType(padding_len, .i8);
                    break :p try o.builder.structConst(
                        try o.builder.structType(.@"packed", &.{ payload_ty, padding_ty }),
                        &.{ payload, try o.builder.undefConst(padding_ty) },
                    );
                } else p: {
                    assert(layout.tag_size == 0);
                    const union_val = try o.lowerValue(un.val);
                    if (container_layout == .Packed) {
                        const bitcast_val = try o.builder.castConst(
                            .bitcast,
                            union_val,
                            try o.builder.intType(@intCast(ty.bitSize(mod))),
                        );
                        return o.builder.convConst(.unsigned, bitcast_val, union_ty);
                    }

                    need_unnamed = true;
                    break :p union_val;
                };

                const payload_ty = payload.typeOf(&o.builder);
                if (layout.tag_size == 0) return o.builder.structConst(if (need_unnamed)
                    try o.builder.structType(union_ty.structKind(&o.builder), &.{payload_ty})
                else
                    union_ty, &.{payload});
                const tag = try o.lowerValue(un.tag);
                const tag_ty = tag.typeOf(&o.builder);
                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                var len: usize = 2;
                if (layout.tag_align.compare(.gte, layout.payload_align)) {
                    fields = .{ tag_ty, payload_ty, undefined };
                    vals = .{ tag, payload, undefined };
                } else {
                    fields = .{ payload_ty, tag_ty, undefined };
                    vals = .{ payload, tag, undefined };
                }
                if (layout.padding != 0) {
                    fields[2] = try o.builder.arrayType(layout.padding, .i8);
                    vals[2] = try o.builder.undefConst(fields[2]);
                    len = 3;
                }
                return o.builder.structConst(if (need_unnamed)
                    try o.builder.structType(union_ty.structKind(&o.builder), fields[0..len])
                else
                    union_ty, vals[0..len]);
            },
            .memoized_call => unreachable,
        };
    }

    fn lowerIntAsPtr(o: *Object, val: InternPool.Index) Allocator.Error!Builder.Constant {
        const mod = o.module;
        switch (mod.intern_pool.indexToKey(val)) {
            .undef => return o.builder.undefConst(.ptr),
            .int => {
                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = Value.fromInterned(val).toBigInt(&bigint_space, mod);
                const llvm_int = try lowerBigInt(o, Type.usize, bigint);
                return o.builder.castConst(.inttoptr, llvm_int, .ptr);
            },
            else => unreachable,
        }
    }

    fn lowerBigInt(
        o: *Object,
        ty: Type,
        bigint: std.math.big.int.Const,
    ) Allocator.Error!Builder.Constant {
        const mod = o.module;
        return o.builder.bigIntConst(try o.builder.intType(ty.intInfo(mod).bits), bigint);
    }

    fn lowerParentPtrDecl(o: *Object, decl_index: InternPool.DeclIndex) Allocator.Error!Builder.Constant {
        const mod = o.module;
        const decl = mod.declPtr(decl_index);
        try mod.markDeclAlive(decl);
        const ptr_ty = try mod.singleMutPtrType(decl.ty);
        return o.lowerDeclRefValue(ptr_ty, decl_index);
    }

    fn lowerParentPtr(o: *Object, ptr_val: Value) Error!Builder.Constant {
        const mod = o.module;
        const ip = &mod.intern_pool;
        const ptr = ip.indexToKey(ptr_val.toIntern()).ptr;
        return switch (ptr.addr) {
            .decl => |decl| try o.lowerParentPtrDecl(decl),
            .mut_decl => |mut_decl| try o.lowerParentPtrDecl(mut_decl.decl),
            .anon_decl => |ad| try o.lowerAnonDeclRef(Type.fromInterned(ad.orig_ty), ad),
            .int => |int| try o.lowerIntAsPtr(int),
            .eu_payload => |eu_ptr| {
                const parent_ptr = try o.lowerParentPtr(Value.fromInterned(eu_ptr));

                const eu_ty = Type.fromInterned(ip.typeOf(eu_ptr)).childType(mod);
                const payload_ty = eu_ty.errorUnionPayload(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    // In this case, we represent pointer to error union the same as pointer
                    // to the payload.
                    return parent_ptr;
                }

                const err_int_ty = try mod.errorIntType();
                const payload_align = payload_ty.abiAlignment(mod);
                const err_align = err_int_ty.abiAlignment(mod);
                const index: u32 = if (payload_align.compare(.gt, err_align)) 2 else 1;
                return o.builder.gepConst(.inbounds, try o.lowerType(eu_ty), parent_ptr, null, &.{
                    try o.builder.intConst(.i32, 0), try o.builder.intConst(.i32, index),
                });
            },
            .opt_payload => |opt_ptr| {
                const parent_ptr = try o.lowerParentPtr(Value.fromInterned(opt_ptr));

                const opt_ty = Type.fromInterned(ip.typeOf(opt_ptr)).childType(mod);
                const payload_ty = opt_ty.optionalChild(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod) or
                    payload_ty.optionalReprIsPayload(mod))
                {
                    // In this case, we represent pointer to optional the same as pointer
                    // to the payload.
                    return parent_ptr;
                }

                return o.builder.gepConst(.inbounds, try o.lowerType(opt_ty), parent_ptr, null, &.{
                    try o.builder.intConst(.i32, 0), try o.builder.intConst(.i32, 0),
                });
            },
            .comptime_field => unreachable,
            .elem => |elem_ptr| {
                const parent_ptr = try o.lowerParentPtr(Value.fromInterned(elem_ptr.base));
                const elem_ty = Type.fromInterned(ip.typeOf(elem_ptr.base)).elemType2(mod);

                return o.builder.gepConst(.inbounds, try o.lowerType(elem_ty), parent_ptr, null, &.{
                    try o.builder.intConst(try o.lowerType(Type.usize), elem_ptr.index),
                });
            },
            .field => |field_ptr| {
                const parent_ptr = try o.lowerParentPtr(Value.fromInterned(field_ptr.base));
                const parent_ptr_ty = Type.fromInterned(ip.typeOf(field_ptr.base));
                const parent_ty = parent_ptr_ty.childType(mod);
                const field_index: u32 = @intCast(field_ptr.index);
                switch (parent_ty.zigTypeTag(mod)) {
                    .Union => {
                        if (parent_ty.containerLayout(mod) == .Packed) {
                            return parent_ptr;
                        }

                        const layout = parent_ty.unionGetLayout(mod);
                        if (layout.payload_size == 0) {
                            // In this case a pointer to the union and a pointer to any
                            // (void) payload is the same.
                            return parent_ptr;
                        }

                        const parent_llvm_ty = try o.lowerType(parent_ty);
                        return o.builder.gepConst(.inbounds, parent_llvm_ty, parent_ptr, null, &.{
                            try o.builder.intConst(.i32, 0),
                            try o.builder.intConst(.i32, @intFromBool(
                                layout.tag_size > 0 and layout.tag_align.compare(.gte, layout.payload_align),
                            )),
                        });
                    },
                    .Struct => {
                        if (mod.typeToPackedStruct(parent_ty)) |struct_type| {
                            const ptr_info = Type.fromInterned(ptr.ty).ptrInfo(mod);
                            if (ptr_info.packed_offset.host_size != 0) return parent_ptr;

                            const parent_ptr_info = parent_ptr_ty.ptrInfo(mod);
                            const bit_offset = mod.structPackedFieldBitOffset(struct_type, field_index) + parent_ptr_info.packed_offset.bit_offset;
                            const llvm_usize = try o.lowerType(Type.usize);
                            const base_addr = try o.builder.castConst(.ptrtoint, parent_ptr, llvm_usize);
                            const byte_offset = try o.builder.intConst(llvm_usize, @divExact(bit_offset, 8));
                            const field_addr = try o.builder.binConst(.add, base_addr, byte_offset);
                            return o.builder.castConst(.inttoptr, field_addr, .ptr);
                        }

                        return o.builder.gepConst(
                            .inbounds,
                            try o.lowerType(parent_ty),
                            parent_ptr,
                            null,
                            if (o.llvmFieldIndex(parent_ty, field_index)) |llvm_field_index| &.{
                                try o.builder.intConst(.i32, 0),
                                try o.builder.intConst(.i32, llvm_field_index),
                            } else &.{
                                try o.builder.intConst(.i32, @intFromBool(
                                    parent_ty.hasRuntimeBitsIgnoreComptime(mod),
                                )),
                            },
                        );
                    },
                    .Pointer => {
                        assert(parent_ty.isSlice(mod));
                        const parent_llvm_ty = try o.lowerType(parent_ty);
                        return o.builder.gepConst(.inbounds, parent_llvm_ty, parent_ptr, null, &.{
                            try o.builder.intConst(.i32, 0), try o.builder.intConst(.i32, field_index),
                        });
                    },
                    else => unreachable,
                }
            },
        };
    }

    /// This logic is very similar to `lowerDeclRefValue` but for anonymous declarations.
    /// Maybe the logic could be unified.
    fn lowerAnonDeclRef(
        o: *Object,
        ptr_ty: Type,
        anon_decl: InternPool.Key.Ptr.Addr.AnonDecl,
    ) Error!Builder.Constant {
        const mod = o.module;
        const ip = &mod.intern_pool;
        const decl_val = anon_decl.val;
        const decl_ty = Type.fromInterned(ip.typeOf(decl_val));
        const target = mod.getTarget();

        if (Value.fromInterned(decl_val).getFunction(mod)) |func| {
            _ = func;
            @panic("TODO");
        } else if (Value.fromInterned(decl_val).getExternFunc(mod)) |func| {
            _ = func;
            @panic("TODO");
        }

        const is_fn_body = decl_ty.zigTypeTag(mod) == .Fn;
        if ((!is_fn_body and !decl_ty.hasRuntimeBits(mod)) or
            (is_fn_body and mod.typeToFunc(decl_ty).?.is_generic)) return o.lowerPtrToVoid(ptr_ty);

        if (is_fn_body)
            @panic("TODO");

        const orig_ty = Type.fromInterned(anon_decl.orig_ty);
        const llvm_addr_space = toLlvmAddressSpace(orig_ty.ptrAddressSpace(mod), target);
        const alignment = orig_ty.ptrAlignment(mod);
        const llvm_global = (try o.resolveGlobalAnonDecl(decl_val, llvm_addr_space, alignment)).ptrConst(&o.builder).global;

        const llvm_val = try o.builder.convConst(
            .unneeded,
            llvm_global.toConst(),
            try o.builder.ptrType(llvm_addr_space),
        );

        return o.builder.convConst(if (ptr_ty.isAbiInt(mod)) switch (ptr_ty.intInfo(mod).signedness) {
            .signed => .signed,
            .unsigned => .unsigned,
        } else .unneeded, llvm_val, try o.lowerType(ptr_ty));
    }

    fn lowerDeclRefValue(o: *Object, ty: Type, decl_index: InternPool.DeclIndex) Allocator.Error!Builder.Constant {
        const mod = o.module;

        // In the case of something like:
        // fn foo() void {}
        // const bar = foo;
        // ... &bar;
        // `bar` is just an alias and we actually want to lower a reference to `foo`.
        const decl = mod.declPtr(decl_index);
        if (decl.val.getFunction(mod)) |func| {
            if (func.owner_decl != decl_index) {
                return o.lowerDeclRefValue(ty, func.owner_decl);
            }
        } else if (decl.val.getExternFunc(mod)) |func| {
            if (func.decl != decl_index) {
                return o.lowerDeclRefValue(ty, func.decl);
            }
        }

        const is_fn_body = decl.ty.zigTypeTag(mod) == .Fn;
        if ((!is_fn_body and !decl.ty.hasRuntimeBits(mod)) or
            (is_fn_body and mod.typeToFunc(decl.ty).?.is_generic)) return o.lowerPtrToVoid(ty);

        try mod.markDeclAlive(decl);

        const llvm_global = if (is_fn_body)
            (try o.resolveLlvmFunction(decl_index)).ptrConst(&o.builder).global
        else
            (try o.resolveGlobalDecl(decl_index)).ptrConst(&o.builder).global;

        const llvm_val = try o.builder.convConst(
            .unneeded,
            llvm_global.toConst(),
            try o.builder.ptrType(toLlvmAddressSpace(decl.@"addrspace", mod.getTarget())),
        );

        return o.builder.convConst(if (ty.isAbiInt(mod)) switch (ty.intInfo(mod).signedness) {
            .signed => .signed,
            .unsigned => .unsigned,
        } else .unneeded, llvm_val, try o.lowerType(ty));
    }

    fn lowerPtrToVoid(o: *Object, ptr_ty: Type) Allocator.Error!Builder.Constant {
        const mod = o.module;
        // Even though we are pointing at something which has zero bits (e.g. `void`),
        // Pointers are defined to have bits. So we must return something here.
        // The value cannot be undefined, because we use the `nonnull` annotation
        // for non-optional pointers. We also need to respect the alignment, even though
        // the address will never be dereferenced.
        const int: u64 = ptr_ty.ptrInfo(mod).flags.alignment.toByteUnitsOptional() orelse
            // Note that these 0xaa values are appropriate even in release-optimized builds
            // because we need a well-defined value that is not null, and LLVM does not
            // have an "undef_but_not_null" attribute. As an example, if this `alloc` AIR
            // instruction is followed by a `wrap_optional`, it will return this value
            // verbatim, and the result should test as non-null.
            switch (mod.getTarget().ptrBitWidth()) {
            16 => 0xaaaa,
            32 => 0xaaaaaaaa,
            64 => 0xaaaaaaaa_aaaaaaaa,
            else => unreachable,
        };
        const llvm_usize = try o.lowerType(Type.usize);
        const llvm_ptr_ty = try o.lowerType(ptr_ty);
        return o.builder.castConst(.inttoptr, try o.builder.intConst(llvm_usize, int), llvm_ptr_ty);
    }

    /// If the operand type of an atomic operation is not byte sized we need to
    /// widen it before using it and then truncate the result.
    /// RMW exchange of floating-point values is bitcasted to same-sized integer
    /// types to work around a LLVM deficiency when targeting ARM/AArch64.
    fn getAtomicAbiType(o: *Object, ty: Type, is_rmw_xchg: bool) Allocator.Error!Builder.Type {
        const mod = o.module;
        const int_ty = switch (ty.zigTypeTag(mod)) {
            .Int => ty,
            .Enum => ty.intTagType(mod),
            .Float => {
                if (!is_rmw_xchg) return .none;
                return o.builder.intType(@intCast(ty.abiSize(mod) * 8));
            },
            .Bool => return .i8,
            else => return .none,
        };
        const bit_count = int_ty.intInfo(mod).bits;
        if (!std.math.isPowerOfTwo(bit_count) or (bit_count % 8) != 0) {
            return o.builder.intType(@intCast(int_ty.abiSize(mod) * 8));
        } else {
            return .none;
        }
    }

    fn addByValParamAttrs(
        o: *Object,
        attributes: *Builder.FunctionAttributes.Wip,
        param_ty: Type,
        param_index: u32,
        fn_info: InternPool.Key.FuncType,
        llvm_arg_i: u32,
    ) Allocator.Error!void {
        const mod = o.module;
        if (param_ty.isPtrAtRuntime(mod)) {
            const ptr_info = param_ty.ptrInfo(mod);
            if (math.cast(u5, param_index)) |i| {
                if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                    try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                }
            }
            if (!param_ty.isPtrLikeOptional(mod) and !ptr_info.flags.is_allowzero) {
                try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            }
            if (ptr_info.flags.is_const) {
                try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
            }
            const elem_align = if (ptr_info.flags.alignment != .none)
                ptr_info.flags.alignment
            else
                Type.fromInterned(ptr_info.child).abiAlignment(mod).max(.@"1");
            try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align.toLlvm() }, &o.builder);
        } else if (ccAbiPromoteInt(fn_info.cc, mod, param_ty)) |s| switch (s) {
            .signed => try attributes.addParamAttr(llvm_arg_i, .signext, &o.builder),
            .unsigned => try attributes.addParamAttr(llvm_arg_i, .zeroext, &o.builder),
        };
    }

    fn addByRefParamAttrs(
        o: *Object,
        attributes: *Builder.FunctionAttributes.Wip,
        llvm_arg_i: u32,
        alignment: Builder.Alignment,
        byval: bool,
        param_llvm_ty: Builder.Type,
    ) Allocator.Error!void {
        try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
        try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
        try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = alignment }, &o.builder);
        if (byval) try attributes.addParamAttr(llvm_arg_i, .{ .byval = param_llvm_ty }, &o.builder);
    }

    fn llvmFieldIndex(o: *Object, struct_ty: Type, field_index: usize) ?c_uint {
        return o.struct_field_map.get(.{
            .struct_ty = struct_ty.toIntern(),
            .field_index = @intCast(field_index),
        });
    }

    fn getCmpLtErrorsLenFunction(o: *Object) !Builder.Function.Index {
        const name = try o.builder.string(lt_errors_fn_name);
        if (o.builder.getGlobal(name)) |llvm_fn| return llvm_fn.ptrConst(&o.builder).kind.function;

        const zcu = o.module;
        const target = zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(.i1, &.{try o.errorIntType()}, .normal),
            name,
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        return function_index;
    }

    fn getEnumTagNameFunction(o: *Object, enum_ty: Type) !Builder.Function.Index {
        const zcu = o.module;
        const ip = &zcu.intern_pool;
        const enum_type = ip.indexToKey(enum_ty.toIntern()).enum_type;

        // TODO: detect when the type changes and re-emit this function.
        const gop = try o.decl_map.getOrPut(o.gpa, enum_type.decl);
        if (gop.found_existing) return gop.value_ptr.ptrConst(&o.builder).kind.function;
        errdefer assert(o.decl_map.remove(enum_type.decl));

        const usize_ty = try o.lowerType(Type.usize);
        const ret_ty = try o.lowerType(Type.slice_const_u8_sentinel_0);
        const fqn = try zcu.declPtr(enum_type.decl).getFullyQualifiedName(zcu);
        const target = zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(ret_ty, &.{try o.lowerType(Type.fromInterned(enum_type.tag_ty))}, .normal),
            try o.builder.fmt("__zig_tag_name_{}", .{fqn.fmt(ip)}),
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        gop.value_ptr.* = function_index.ptrConst(&o.builder).global;

        var wip = try Builder.WipFunction.init(&o.builder, function_index);
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        const bad_value_block = try wip.block(1, "BadValue");
        const tag_int_value = wip.arg(0);
        var wip_switch =
            try wip.@"switch"(tag_int_value, bad_value_block, @intCast(enum_type.names.len));
        defer wip_switch.finish(&wip);

        for (0..enum_type.names.len) |field_index| {
            const name = try o.builder.string(ip.stringToSlice(enum_type.names.get(ip)[field_index]));
            const name_init = try o.builder.stringNullConst(name);
            const name_variable_index =
                try o.builder.addVariable(.empty, name_init.typeOf(&o.builder), .default);
            try name_variable_index.setInitializer(name_init, &o.builder);
            name_variable_index.setLinkage(.private, &o.builder);
            name_variable_index.setMutability(.constant, &o.builder);
            name_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
            name_variable_index.setAlignment(comptime Builder.Alignment.fromByteUnits(1), &o.builder);

            const name_val = try o.builder.structValue(ret_ty, &.{
                name_variable_index.toConst(&o.builder),
                try o.builder.intConst(usize_ty, name.slice(&o.builder).?.len),
            });

            const return_block = try wip.block(1, "Name");
            const this_tag_int_value = try o.lowerValue(
                (try zcu.enumValueFieldIndex(enum_ty, @intCast(field_index))).toIntern(),
            );
            try wip_switch.addCase(this_tag_int_value, return_block, &wip);

            wip.cursor = .{ .block = return_block };
            _ = try wip.ret(name_val);
        }

        wip.cursor = .{ .block = bad_value_block };
        _ = try wip.@"unreachable"();

        try wip.finish();
        return function_index;
    }
};

pub const DeclGen = struct {
    object: *Object,
    decl: *Module.Decl,
    decl_index: InternPool.DeclIndex,
    err_msg: ?*Module.ErrorMsg,

    fn ownerModule(dg: DeclGen) *Package.Module {
        const o = dg.object;
        const zcu = o.module;
        const namespace = zcu.namespacePtr(dg.decl.src_namespace);
        return namespace.file_scope.mod;
    }

    fn todo(dg: *DeclGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        assert(dg.err_msg == null);
        const o = dg.object;
        const gpa = o.gpa;
        const mod = o.module;
        const src_loc = LazySrcLoc.nodeOffset(0).toSrcLoc(dg.decl, mod);
        dg.err_msg = try Module.ErrorMsg.create(gpa, src_loc, "TODO (LLVM): " ++ format, args);
        return error.CodegenFail;
    }

    fn genDecl(dg: *DeclGen) !void {
        const o = dg.object;
        const mod = o.module;
        const decl = dg.decl;
        const decl_index = dg.decl_index;
        assert(decl.has_tv);

        if (decl.val.getExternFunc(mod)) |extern_func| {
            _ = try o.resolveLlvmFunction(extern_func.decl);
        } else {
            const variable_index = try o.resolveGlobalDecl(decl_index);
            variable_index.setAlignment(
                decl.getAlignment(mod).toLlvm(),
                &o.builder,
            );
            if (mod.intern_pool.stringToSliceUnwrap(decl.@"linksection")) |section|
                variable_index.setSection(try o.builder.string(section), &o.builder);
            assert(decl.has_tv);
            const init_val = if (decl.val.getVariable(mod)) |decl_var| decl_var.init else init_val: {
                variable_index.setMutability(.constant, &o.builder);
                break :init_val decl.val.toIntern();
            };
            try variable_index.setInitializer(switch (init_val) {
                .none => .no_init,
                else => try o.lowerValue(init_val),
            }, &o.builder);

            if (o.di_builder) |dib| {
                const di_file =
                    try o.getDIFile(o.gpa, mod.namespacePtr(decl.src_namespace).file_scope);

                const line_number = decl.src_line + 1;
                const is_internal_linkage = !o.module.decl_exports.contains(decl_index);
                const di_global = dib.createGlobalVariableExpression(
                    di_file.toScope(),
                    mod.intern_pool.stringToSlice(decl.name),
                    variable_index.name(&o.builder).slice(&o.builder).?,
                    di_file,
                    line_number,
                    try o.lowerDebugType(decl.ty, .full),
                    is_internal_linkage,
                );

                try o.di_map.put(o.gpa, dg.decl, di_global.getVariable().toNode());
                if (!is_internal_linkage or decl.isExtern(mod))
                    variable_index.toLlvm(&o.builder).attachMetaData(di_global);
            }
        }
    }
};

pub const FuncGen = struct {
    gpa: Allocator,
    dg: *DeclGen,
    air: Air,
    liveness: Liveness,
    wip: Builder.WipFunction,
    di_scope: ?if (build_options.have_llvm) *llvm.DIScope else noreturn,
    di_file: ?if (build_options.have_llvm) *llvm.DIFile else noreturn,
    base_line: u32,
    prev_dbg_line: c_uint,
    prev_dbg_column: c_uint,

    /// Stack of locations where a call was inlined.
    dbg_inlined: std.ArrayListUnmanaged(if (build_options.have_llvm) DbgState else void) = .{},

    /// Stack of `DILexicalBlock`s. dbg_block instructions cannot happend accross
    /// dbg_inline instructions so no special handling there is required.
    dbg_block_stack: std.ArrayListUnmanaged(if (build_options.have_llvm) *llvm.DIScope else void) = .{},

    /// This stores the LLVM values used in a function, such that they can be referred to
    /// in other instructions. This table is cleared before every function is generated.
    func_inst_table: std.AutoHashMapUnmanaged(Air.Inst.Ref, Builder.Value),

    /// If the return type is sret, this is the result pointer. Otherwise null.
    /// Note that this can disagree with isByRef for the return type in the case
    /// of C ABI functions.
    ret_ptr: Builder.Value,
    /// Any function that needs to perform Valgrind client requests needs an array alloca
    /// instruction, however a maximum of one per function is needed.
    valgrind_client_request_array: Builder.Value = .none,
    /// These fields are used to refer to the LLVM value of the function parameters
    /// in an Arg instruction.
    /// This list may be shorter than the list according to the zig type system;
    /// it omits 0-bit types. If the function uses sret as the first parameter,
    /// this slice does not include it.
    args: []const Builder.Value,
    arg_index: usize,

    err_ret_trace: Builder.Value = .none,

    /// This data structure is used to implement breaking to blocks.
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
        parent_bb: Builder.Function.Block.Index,
        breaks: *BreakList,
    }),

    sync_scope: Builder.SyncScope,

    const DbgState = if (build_options.have_llvm) struct { loc: *llvm.DILocation, scope: *llvm.DIScope, base_line: u32 } else struct {};
    const BreakList = union {
        list: std.MultiArrayList(struct {
            bb: Builder.Function.Block.Index,
            val: Builder.Value,
        }),
        len: usize,
    };

    fn deinit(self: *FuncGen) void {
        self.wip.deinit();
        self.dbg_inlined.deinit(self.gpa);
        self.dbg_block_stack.deinit(self.gpa);
        self.func_inst_table.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
    }

    fn todo(self: *FuncGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        return self.dg.todo(format, args);
    }

    fn resolveInst(self: *FuncGen, inst: Air.Inst.Ref) !Builder.Value {
        const gpa = self.gpa;
        const gop = try self.func_inst_table.getOrPut(gpa, inst);
        if (gop.found_existing) return gop.value_ptr.*;

        const o = self.dg.object;
        const mod = o.module;
        const llvm_val = try self.resolveValue(.{
            .ty = self.typeOf(inst),
            .val = (try self.air.value(inst, mod)).?,
        });
        gop.value_ptr.* = llvm_val.toValue();
        return llvm_val.toValue();
    }

    fn resolveValue(self: *FuncGen, tv: TypedValue) Error!Builder.Constant {
        const o = self.dg.object;
        const mod = o.module;
        const llvm_val = try o.lowerValue(tv.val.toIntern());
        if (!isByRef(tv.ty, mod)) return llvm_val;

        // We have an LLVM value but we need to create a global constant and
        // set the value as its initializer, and then return a pointer to the global.
        const target = mod.getTarget();
        const variable_index = try o.builder.addVariable(
            .empty,
            llvm_val.typeOf(&o.builder),
            toLlvmGlobalAddressSpace(.generic, target),
        );
        try variable_index.setInitializer(llvm_val, &o.builder);
        variable_index.setLinkage(.private, &o.builder);
        variable_index.setMutability(.constant, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(tv.ty.abiAlignment(mod).toLlvm(), &o.builder);
        return o.builder.convConst(
            .unneeded,
            variable_index.toConst(&o.builder),
            try o.builder.ptrType(toLlvmAddressSpace(.generic, target)),
        );
    }

    fn resolveNullOptUsize(self: *FuncGen) Error!Builder.Constant {
        const o = self.dg.object;
        const mod = o.module;
        if (o.null_opt_usize == .no_init) {
            const ty = try mod.intern(.{ .opt_type = .usize_type });
            o.null_opt_usize = try self.resolveValue(.{
                .ty = Type.fromInterned(ty),
                .val = Value.fromInterned((try mod.intern(.{ .opt = .{ .ty = ty, .val = .none } }))),
            });
        }
        return o.null_opt_usize;
    }

    fn genBody(self: *FuncGen, body: []const Air.Inst.Index) Error!void {
        const o = self.dg.object;
        const mod = o.module;
        const ip = &mod.intern_pool;
        const air_tags = self.air.instructions.items(.tag);
        for (body, 0..) |inst, i| {
            if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip)) continue;

            const val: Builder.Value = switch (air_tags[@intFromEnum(inst)]) {
                // zig fmt: off
                .add            => try self.airAdd(inst, .normal),
                .add_optimized  => try self.airAdd(inst, .fast),
                .add_wrap       => try self.airAddWrap(inst),
                .add_sat        => try self.airAddSat(inst),

                .sub            => try self.airSub(inst, .normal),
                .sub_optimized  => try self.airSub(inst, .fast),
                .sub_wrap       => try self.airSubWrap(inst),
                .sub_sat        => try self.airSubSat(inst),

                .mul           => try self.airMul(inst, .normal),
                .mul_optimized => try self.airMul(inst, .fast),
                .mul_wrap      => try self.airMulWrap(inst),
                .mul_sat       => try self.airMulSat(inst),

                .add_safe => try self.airSafeArithmetic(inst, .@"sadd.with.overflow", .@"uadd.with.overflow"),
                .sub_safe => try self.airSafeArithmetic(inst, .@"ssub.with.overflow", .@"usub.with.overflow"),
                .mul_safe => try self.airSafeArithmetic(inst, .@"smul.with.overflow", .@"umul.with.overflow"),

                .div_float => try self.airDivFloat(inst, .normal),
                .div_trunc => try self.airDivTrunc(inst, .normal),
                .div_floor => try self.airDivFloor(inst, .normal),
                .div_exact => try self.airDivExact(inst, .normal),
                .rem       => try self.airRem(inst, .normal),
                .mod       => try self.airMod(inst, .normal),
                .abs       => try self.airAbs(inst),
                .ptr_add   => try self.airPtrAdd(inst),
                .ptr_sub   => try self.airPtrSub(inst),
                .shl       => try self.airShl(inst),
                .shl_sat   => try self.airShlSat(inst),
                .shl_exact => try self.airShlExact(inst),
                .min       => try self.airMin(inst),
                .max       => try self.airMax(inst),
                .slice     => try self.airSlice(inst),
                .mul_add   => try self.airMulAdd(inst),

                .div_float_optimized => try self.airDivFloat(inst, .fast),
                .div_trunc_optimized => try self.airDivTrunc(inst, .fast),
                .div_floor_optimized => try self.airDivFloor(inst, .fast),
                .div_exact_optimized => try self.airDivExact(inst, .fast),
                .rem_optimized       => try self.airRem(inst, .fast),
                .mod_optimized       => try self.airMod(inst, .fast),

                .add_with_overflow => try self.airOverflow(inst, .@"sadd.with.overflow", .@"uadd.with.overflow"),
                .sub_with_overflow => try self.airOverflow(inst, .@"ssub.with.overflow", .@"usub.with.overflow"),
                .mul_with_overflow => try self.airOverflow(inst, .@"smul.with.overflow", .@"umul.with.overflow"),
                .shl_with_overflow => try self.airShlWithOverflow(inst),

                .bit_and, .bool_and => try self.airAnd(inst),
                .bit_or, .bool_or   => try self.airOr(inst),
                .xor                => try self.airXor(inst),
                .shr                => try self.airShr(inst, false),
                .shr_exact          => try self.airShr(inst, true),

                .sqrt         => try self.airUnaryOp(inst, .sqrt),
                .sin          => try self.airUnaryOp(inst, .sin),
                .cos          => try self.airUnaryOp(inst, .cos),
                .tan          => try self.airUnaryOp(inst, .tan),
                .exp          => try self.airUnaryOp(inst, .exp),
                .exp2         => try self.airUnaryOp(inst, .exp2),
                .log          => try self.airUnaryOp(inst, .log),
                .log2         => try self.airUnaryOp(inst, .log2),
                .log10        => try self.airUnaryOp(inst, .log10),
                .floor        => try self.airUnaryOp(inst, .floor),
                .ceil         => try self.airUnaryOp(inst, .ceil),
                .round        => try self.airUnaryOp(inst, .round),
                .trunc_float  => try self.airUnaryOp(inst, .trunc),

                .neg           => try self.airNeg(inst, .normal),
                .neg_optimized => try self.airNeg(inst, .fast),

                .cmp_eq  => try self.airCmp(inst, .eq, .normal),
                .cmp_gt  => try self.airCmp(inst, .gt, .normal),
                .cmp_gte => try self.airCmp(inst, .gte, .normal),
                .cmp_lt  => try self.airCmp(inst, .lt, .normal),
                .cmp_lte => try self.airCmp(inst, .lte, .normal),
                .cmp_neq => try self.airCmp(inst, .neq, .normal),

                .cmp_eq_optimized  => try self.airCmp(inst, .eq, .fast),
                .cmp_gt_optimized  => try self.airCmp(inst, .gt, .fast),
                .cmp_gte_optimized => try self.airCmp(inst, .gte, .fast),
                .cmp_lt_optimized  => try self.airCmp(inst, .lt, .fast),
                .cmp_lte_optimized => try self.airCmp(inst, .lte, .fast),
                .cmp_neq_optimized => try self.airCmp(inst, .neq, .fast),

                .cmp_vector           => try self.airCmpVector(inst, .normal),
                .cmp_vector_optimized => try self.airCmpVector(inst, .fast),
                .cmp_lt_errors_len    => try self.airCmpLtErrorsLen(inst),

                .is_non_null     => try self.airIsNonNull(inst, false, .ne),
                .is_non_null_ptr => try self.airIsNonNull(inst, true , .ne),
                .is_null         => try self.airIsNonNull(inst, false, .eq),
                .is_null_ptr     => try self.airIsNonNull(inst, true , .eq),

                .is_non_err      => try self.airIsErr(inst, .eq, false),
                .is_non_err_ptr  => try self.airIsErr(inst, .eq, true),
                .is_err          => try self.airIsErr(inst, .ne, false),
                .is_err_ptr      => try self.airIsErr(inst, .ne, true),

                .alloc          => try self.airAlloc(inst),
                .ret_ptr        => try self.airRetPtr(inst),
                .arg            => try self.airArg(inst),
                .bitcast        => try self.airBitCast(inst),
                .int_from_bool    => try self.airIntFromBool(inst),
                .block          => try self.airBlock(inst),
                .br             => try self.airBr(inst),
                .switch_br      => try self.airSwitchBr(inst),
                .trap           => try self.airTrap(inst),
                .breakpoint     => try self.airBreakpoint(inst),
                .ret_addr       => try self.airRetAddr(inst),
                .frame_addr     => try self.airFrameAddress(inst),
                .cond_br        => try self.airCondBr(inst),
                .@"try"         => try self.airTry(body[i..]),
                .try_ptr        => try self.airTryPtr(inst),
                .intcast        => try self.airIntCast(inst),
                .trunc          => try self.airTrunc(inst),
                .fptrunc        => try self.airFptrunc(inst),
                .fpext          => try self.airFpext(inst),
                .int_from_ptr       => try self.airIntFromPtr(inst),
                .load           => try self.airLoad(body[i..]),
                .loop           => try self.airLoop(inst),
                .not            => try self.airNot(inst),
                .ret            => try self.airRet(inst),
                .ret_load       => try self.airRetLoad(inst),
                .store          => try self.airStore(inst, false),
                .store_safe     => try self.airStore(inst, true),
                .assembly       => try self.airAssembly(inst),
                .slice_ptr      => try self.airSliceField(inst, 0),
                .slice_len      => try self.airSliceField(inst, 1),

                .call              => try self.airCall(inst, .auto),
                .call_always_tail  => try self.airCall(inst, .always_tail),
                .call_never_tail   => try self.airCall(inst, .never_tail),
                .call_never_inline => try self.airCall(inst, .never_inline),

                .ptr_slice_ptr_ptr => try self.airPtrSliceFieldPtr(inst, 0),
                .ptr_slice_len_ptr => try self.airPtrSliceFieldPtr(inst, 1),

                .int_from_float           => try self.airIntFromFloat(inst, .normal),
                .int_from_float_optimized => try self.airIntFromFloat(inst, .fast),

                .array_to_slice => try self.airArrayToSlice(inst),
                .float_from_int => try self.airFloatFromInt(inst),
                .cmpxchg_weak   => try self.airCmpxchg(inst, .weak),
                .cmpxchg_strong => try self.airCmpxchg(inst, .strong),
                .fence          => try self.airFence(inst),
                .atomic_rmw     => try self.airAtomicRmw(inst),
                .atomic_load    => try self.airAtomicLoad(inst),
                .memset         => try self.airMemset(inst, false),
                .memset_safe    => try self.airMemset(inst, true),
                .memcpy         => try self.airMemcpy(inst),
                .set_union_tag  => try self.airSetUnionTag(inst),
                .get_union_tag  => try self.airGetUnionTag(inst),
                .clz            => try self.airClzCtz(inst, .ctlz),
                .ctz            => try self.airClzCtz(inst, .cttz),
                .popcount       => try self.airBitOp(inst, .ctpop),
                .byte_swap      => try self.airByteSwap(inst),
                .bit_reverse    => try self.airBitOp(inst, .bitreverse),
                .tag_name       => try self.airTagName(inst),
                .error_name     => try self.airErrorName(inst),
                .splat          => try self.airSplat(inst),
                .select         => try self.airSelect(inst),
                .shuffle        => try self.airShuffle(inst),
                .aggregate_init => try self.airAggregateInit(inst),
                .union_init     => try self.airUnionInit(inst),
                .prefetch       => try self.airPrefetch(inst),
                .addrspace_cast => try self.airAddrSpaceCast(inst),

                .is_named_enum_value => try self.airIsNamedEnumValue(inst),
                .error_set_has_value => try self.airErrorSetHasValue(inst),

                .reduce           => try self.airReduce(inst, .normal),
                .reduce_optimized => try self.airReduce(inst, .fast),

                .atomic_store_unordered => try self.airAtomicStore(inst, .unordered),
                .atomic_store_monotonic => try self.airAtomicStore(inst, .monotonic),
                .atomic_store_release   => try self.airAtomicStore(inst, .release),
                .atomic_store_seq_cst   => try self.airAtomicStore(inst, .seq_cst),

                .struct_field_ptr => try self.airStructFieldPtr(inst),
                .struct_field_val => try self.airStructFieldVal(body[i..]),

                .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
                .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
                .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
                .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

                .field_parent_ptr => try self.airFieldParentPtr(inst),

                .array_elem_val     => try self.airArrayElemVal(body[i..]),
                .slice_elem_val     => try self.airSliceElemVal(body[i..]),
                .slice_elem_ptr     => try self.airSliceElemPtr(inst),
                .ptr_elem_val       => try self.airPtrElemVal(body[i..]),
                .ptr_elem_ptr       => try self.airPtrElemPtr(inst),

                .optional_payload         => try self.airOptionalPayload(body[i..]),
                .optional_payload_ptr     => try self.airOptionalPayloadPtr(inst),
                .optional_payload_ptr_set => try self.airOptionalPayloadPtrSet(inst),

                .unwrap_errunion_payload     => try self.airErrUnionPayload(body[i..], false),
                .unwrap_errunion_payload_ptr => try self.airErrUnionPayload(body[i..], true),
                .unwrap_errunion_err         => try self.airErrUnionErr(inst, false),
                .unwrap_errunion_err_ptr     => try self.airErrUnionErr(inst, true),
                .errunion_payload_ptr_set    => try self.airErrUnionPayloadPtrSet(inst),
                .err_return_trace            => try self.airErrReturnTrace(inst),
                .set_err_return_trace        => try self.airSetErrReturnTrace(inst),
                .save_err_return_trace_index => try self.airSaveErrReturnTraceIndex(inst),

                .wrap_optional         => try self.airWrapOptional(body[i..]),
                .wrap_errunion_payload => try self.airWrapErrUnionPayload(body[i..]),
                .wrap_errunion_err     => try self.airWrapErrUnionErr(body[i..]),

                .wasm_memory_size => try self.airWasmMemorySize(inst),
                .wasm_memory_grow => try self.airWasmMemoryGrow(inst),

                .vector_store_elem => try self.airVectorStoreElem(inst),

                .inferred_alloc, .inferred_alloc_comptime => unreachable,

                .unreach  => try self.airUnreach(inst),
                .dbg_stmt => try self.airDbgStmt(inst),
                .dbg_inline_begin => try self.airDbgInlineBegin(inst),
                .dbg_inline_end => try self.airDbgInlineEnd(inst),
                .dbg_block_begin => try self.airDbgBlockBegin(),
                .dbg_block_end => try self.airDbgBlockEnd(),
                .dbg_var_ptr => try self.airDbgVarPtr(inst),
                .dbg_var_val => try self.airDbgVarVal(inst),

                .c_va_arg => try self.airCVaArg(inst),
                .c_va_copy => try self.airCVaCopy(inst),
                .c_va_end => try self.airCVaEnd(inst),
                .c_va_start => try self.airCVaStart(inst),

                .work_item_id => try self.airWorkItemId(inst),
                .work_group_size => try self.airWorkGroupSize(inst),
                .work_group_id => try self.airWorkGroupId(inst),
                // zig fmt: on
            };
            if (val != .none) try self.func_inst_table.putNoClobber(self.gpa, inst.toRef(), val);
        }
    }

    pub const CallAttr = enum {
        Auto,
        NeverTail,
        NeverInline,
        AlwaysTail,
        AlwaysInline,
    };

    fn airCall(self: *FuncGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);
        const o = self.dg.object;
        const mod = o.module;
        const ip = &mod.intern_pool;
        const callee_ty = self.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag(mod)) {
            .Fn => callee_ty,
            .Pointer => callee_ty.childType(mod),
            else => unreachable,
        };
        const fn_info = mod.typeToFunc(zig_fn_ty).?;
        const return_type = Type.fromInterned(fn_info.return_type);
        const llvm_fn = try self.resolveInst(pl_op.operand);
        const target = mod.getTarget();
        const sret = firstParamSRet(fn_info, mod);

        var llvm_args = std.ArrayList(Builder.Value).init(self.gpa);
        defer llvm_args.deinit();

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);

        switch (modifier) {
            .auto, .never_tail, .always_tail => {},
            .never_inline => try attributes.addFnAttr(.@"noinline", &o.builder),
            .async_kw, .no_async, .always_inline, .compile_time => unreachable,
        }

        const ret_ptr = if (!sret) null else blk: {
            const llvm_ret_ty = try o.lowerType(return_type);
            try attributes.addParamAttr(0, .{ .sret = llvm_ret_ty }, &o.builder);

            const alignment = return_type.abiAlignment(mod).toLlvm();
            const ret_ptr = try self.buildAllocaWorkaround(return_type, alignment);
            try llvm_args.append(ret_ptr);
            break :blk ret_ptr;
        };

        const err_return_tracing = return_type.isError(mod) and
            o.module.comp.config.any_error_tracing;
        if (err_return_tracing) {
            assert(self.err_ret_trace != .none);
            try llvm_args.append(self.err_ret_trace);
        }

        var it = iterateParamTypes(o, fn_info);
        while (try it.nextCall(self, args)) |lowering| switch (lowering) {
            .no_bits => continue,
            .byval => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                const llvm_param_ty = try o.lowerType(param_ty);
                if (isByRef(param_ty, mod)) {
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    const loaded = try self.wip.load(.normal, llvm_param_ty, llvm_arg, alignment, "");
                    try llvm_args.append(loaded);
                } else {
                    try llvm_args.append(llvm_arg);
                }
            },
            .byref => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                if (isByRef(param_ty, mod)) {
                    try llvm_args.append(llvm_arg);
                } else {
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    const param_llvm_ty = llvm_arg.typeOfWip(&self.wip);
                    const arg_ptr = try self.buildAlloca(param_llvm_ty, alignment);
                    _ = try self.wip.store(.normal, llvm_arg, arg_ptr, alignment);
                    try llvm_args.append(arg_ptr);
                }
            },
            .byref_mut => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);

                const alignment = param_ty.abiAlignment(mod).toLlvm();
                const param_llvm_ty = try o.lowerType(param_ty);
                const arg_ptr = try self.buildAllocaWorkaround(param_ty, alignment);
                if (isByRef(param_ty, mod)) {
                    const loaded = try self.wip.load(.normal, param_llvm_ty, llvm_arg, alignment, "");
                    _ = try self.wip.store(.normal, loaded, arg_ptr, alignment);
                } else {
                    _ = try self.wip.store(.normal, llvm_arg, arg_ptr, alignment);
                }
                try llvm_args.append(arg_ptr);
            },
            .abi_sized_int => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                const int_llvm_ty = try o.builder.intType(@intCast(param_ty.abiSize(mod) * 8));

                if (isByRef(param_ty, mod)) {
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    const loaded = try self.wip.load(.normal, int_llvm_ty, llvm_arg, alignment, "");
                    try llvm_args.append(loaded);
                } else {
                    // LLVM does not allow bitcasting structs so we must allocate
                    // a local, store as one type, and then load as another type.
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    const int_ptr = try self.buildAllocaWorkaround(param_ty, alignment);
                    _ = try self.wip.store(.normal, llvm_arg, int_ptr, alignment);
                    const loaded = try self.wip.load(.normal, int_llvm_ty, int_ptr, alignment, "");
                    try llvm_args.append(loaded);
                }
            },
            .slice => {
                const arg = args[it.zig_index - 1];
                const llvm_arg = try self.resolveInst(arg);
                const ptr = try self.wip.extractValue(llvm_arg, &.{0}, "");
                const len = try self.wip.extractValue(llvm_arg, &.{1}, "");
                try llvm_args.appendSlice(&.{ ptr, len });
            },
            .multiple_llvm_types => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_types = it.types_buffer[0..it.types_len];
                const llvm_arg = try self.resolveInst(arg);
                const is_by_ref = isByRef(param_ty, mod);
                const arg_ptr = if (is_by_ref) llvm_arg else ptr: {
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    break :ptr ptr;
                };

                const llvm_ty = try o.builder.structType(.normal, llvm_types);
                try llvm_args.ensureUnusedCapacity(it.types_len);
                for (llvm_types, 0..) |field_ty, i| {
                    const alignment =
                        Builder.Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8));
                    const field_ptr = try self.wip.gepStruct(llvm_ty, arg_ptr, i, "");
                    const loaded = try self.wip.load(.normal, field_ty, field_ptr, alignment, "");
                    llvm_args.appendAssumeCapacity(loaded);
                }
            },
            .as_u16 => {
                const arg = args[it.zig_index - 1];
                const llvm_arg = try self.resolveInst(arg);
                const casted = try self.wip.cast(.bitcast, llvm_arg, .i16, "");
                try llvm_args.append(casted);
            },
            .float_array => |count| {
                const arg = args[it.zig_index - 1];
                const arg_ty = self.typeOf(arg);
                var llvm_arg = try self.resolveInst(arg);
                const alignment = arg_ty.abiAlignment(mod).toLlvm();
                if (!isByRef(arg_ty, mod)) {
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    llvm_arg = ptr;
                }

                const float_ty = try o.lowerType(aarch64_c_abi.getFloatArrayType(arg_ty, mod).?);
                const array_ty = try o.builder.arrayType(count, float_ty);

                const loaded = try self.wip.load(.normal, array_ty, llvm_arg, alignment, "");
                try llvm_args.append(loaded);
            },
            .i32_array, .i64_array => |arr_len| {
                const elem_size: u8 = if (lowering == .i32_array) 32 else 64;
                const arg = args[it.zig_index - 1];
                const arg_ty = self.typeOf(arg);
                var llvm_arg = try self.resolveInst(arg);
                const alignment = arg_ty.abiAlignment(mod).toLlvm();
                if (!isByRef(arg_ty, mod)) {
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    llvm_arg = ptr;
                }

                const array_ty =
                    try o.builder.arrayType(arr_len, try o.builder.intType(@intCast(elem_size)));
                const loaded = try self.wip.load(.normal, array_ty, llvm_arg, alignment, "");
                try llvm_args.append(loaded);
            },
        };

        {
            // Add argument attributes.
            it = iterateParamTypes(o, fn_info);
            it.llvm_index += @intFromBool(sret);
            it.llvm_index += @intFromBool(err_return_tracing);
            while (try it.next()) |lowering| switch (lowering) {
                .byval => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    if (!isByRef(param_ty, mod)) {
                        try o.addByValParamAttrs(&attributes, param_ty, param_index, fn_info, it.llvm_index - 1);
                    }
                },
                .byref => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    const param_llvm_ty = try o.lowerType(param_ty);
                    const alignment = param_ty.abiAlignment(mod).toLlvm();
                    try o.addByRefParamAttrs(&attributes, it.llvm_index - 1, alignment, it.byval_attr, param_llvm_ty);
                },
                .byref_mut => try attributes.addParamAttr(it.llvm_index - 1, .noundef, &o.builder),
                // No attributes needed for these.
                .no_bits,
                .abi_sized_int,
                .multiple_llvm_types,
                .as_u16,
                .float_array,
                .i32_array,
                .i64_array,
                => continue,

                .slice => {
                    assert(!it.byval_attr);
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                    const ptr_info = param_ty.ptrInfo(mod);
                    const llvm_arg_i = it.llvm_index - 2;

                    if (math.cast(u5, it.zig_index - 1)) |i| {
                        if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                            try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                        }
                    }
                    if (param_ty.zigTypeTag(mod) != .Optional) {
                        try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
                    }
                    if (ptr_info.flags.is_const) {
                        try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
                    }
                    const elem_align = (if (ptr_info.flags.alignment != .none)
                        @as(InternPool.Alignment, ptr_info.flags.alignment)
                    else
                        Type.fromInterned(ptr_info.child).abiAlignment(mod).max(.@"1")).toLlvm();
                    try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align }, &o.builder);
                },
            };
        }

        const call = try self.wip.call(
            switch (modifier) {
                .auto, .never_inline => .normal,
                .never_tail => .notail,
                .always_tail => .musttail,
                .async_kw, .no_async, .always_inline, .compile_time => unreachable,
            },
            toLlvmCallConv(fn_info.cc, target),
            try attributes.finish(&o.builder),
            try o.lowerType(zig_fn_ty),
            llvm_fn,
            llvm_args.items,
            "",
        );

        if (fn_info.return_type == .noreturn_type and modifier != .always_tail) {
            return .none;
        }

        if (self.liveness.isUnused(inst) or !return_type.hasRuntimeBitsIgnoreComptime(mod)) {
            return .none;
        }

        const llvm_ret_ty = try o.lowerType(return_type);
        if (ret_ptr) |rp| {
            if (isByRef(return_type, mod)) {
                return rp;
            } else {
                // our by-ref status disagrees with sret so we must load.
                const return_alignment = return_type.abiAlignment(mod).toLlvm();
                return self.wip.load(.normal, llvm_ret_ty, rp, return_alignment, "");
            }
        }

        const abi_ret_ty = try lowerFnRetTy(o, fn_info);

        if (abi_ret_ty != llvm_ret_ty) {
            // In this case the function return type is honoring the calling convention by having
            // a different LLVM type than the usual one. We solve this here at the callsite
            // by using our canonical type, then loading it if necessary.
            const alignment = return_type.abiAlignment(mod).toLlvm();
            if (o.builder.useLibLlvm())
                assert(o.target_data.abiSizeOfType(abi_ret_ty.toLlvm(&o.builder)) >=
                    o.target_data.abiSizeOfType(llvm_ret_ty.toLlvm(&o.builder)));
            const rp = try self.buildAlloca(abi_ret_ty, alignment);
            _ = try self.wip.store(.normal, call, rp, alignment);
            return if (isByRef(return_type, mod))
                rp
            else
                try self.wip.load(.normal, llvm_ret_ty, rp, alignment, "");
        }

        if (isByRef(return_type, mod)) {
            // our by-ref status disagrees with sret so we must allocate, store,
            // and return the allocation pointer.
            const alignment = return_type.abiAlignment(mod).toLlvm();
            const rp = try self.buildAlloca(llvm_ret_ty, alignment);
            _ = try self.wip.store(.normal, call, rp, alignment);
            return rp;
        } else {
            return call;
        }
    }

    fn buildSimplePanic(fg: *FuncGen, panic_id: Module.PanicId) !void {
        const o = fg.dg.object;
        const mod = o.module;
        const msg_decl_index = mod.panic_messages[@intFromEnum(panic_id)].unwrap().?;
        const msg_decl = mod.declPtr(msg_decl_index);
        const msg_len = msg_decl.ty.childType(mod).arrayLen(mod);
        const msg_ptr = try o.lowerValue(try msg_decl.internValue(mod));
        const null_opt_addr_global = try fg.resolveNullOptUsize();
        const target = mod.getTarget();
        const llvm_usize = try o.lowerType(Type.usize);
        // example:
        // call fastcc void @test2.panic(
        //   ptr @builtin.panic_messages.integer_overflow__anon_987, ; msg.ptr
        //   i64 16,                                                 ; msg.len
        //   ptr null,                                               ; stack trace
        //   ptr @2,                                                 ; addr (null ?usize)
        // )
        const panic_func = mod.funcInfo(mod.panic_func_index);
        const panic_decl = mod.declPtr(panic_func.owner_decl);
        const fn_info = mod.typeToFunc(panic_decl.ty).?;
        const panic_global = try o.resolveLlvmFunction(panic_func.owner_decl);
        _ = try fg.wip.call(
            .normal,
            toLlvmCallConv(fn_info.cc, target),
            .none,
            panic_global.typeOf(&o.builder),
            panic_global.toValue(&o.builder),
            &.{
                msg_ptr.toValue(),
                try o.builder.intValue(llvm_usize, msg_len),
                try o.builder.nullValue(.ptr),
                null_opt_addr_global.toValue(),
            },
            "",
        );
        _ = try fg.wip.@"unreachable"();
    }

    fn airRet(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ret_ty = self.typeOf(un_op);
        if (self.ret_ptr != .none) {
            const operand = try self.resolveInst(un_op);
            const ptr_ty = try mod.singleMutPtrType(ret_ty);

            const unwrapped_operand = operand.unwrap();
            const unwrapped_ret = self.ret_ptr.unwrap();

            // Return value was stored previously
            if (unwrapped_operand == .instruction and unwrapped_ret == .instruction and unwrapped_operand.instruction == unwrapped_ret.instruction) {
                _ = try self.wip.retVoid();
                return .none;
            }

            try self.store(self.ret_ptr, ptr_ty, operand, .none);
            _ = try self.wip.retVoid();
            return .none;
        }
        const fn_info = mod.typeToFunc(self.dg.decl.ty).?;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            if (Type.fromInterned(fn_info.return_type).isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                _ = try self.wip.ret(try o.builder.intValue(try o.errorIntType(), 0));
            } else {
                _ = try self.wip.retVoid();
            }
            return .none;
        }

        const abi_ret_ty = try lowerFnRetTy(o, fn_info);
        const operand = try self.resolveInst(un_op);
        const alignment = ret_ty.abiAlignment(mod).toLlvm();

        if (isByRef(ret_ty, mod)) {
            // operand is a pointer however self.ret_ptr is null so that means
            // we need to return a value.
            _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, operand, alignment, ""));
            return .none;
        }

        const llvm_ret_ty = operand.typeOfWip(&self.wip);
        if (abi_ret_ty == llvm_ret_ty) {
            _ = try self.wip.ret(operand);
            return .none;
        }

        const rp = try self.buildAlloca(llvm_ret_ty, alignment);
        _ = try self.wip.store(.normal, operand, rp, alignment);
        _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, rp, alignment, ""));
        return .none;
    }

    fn airRetLoad(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ptr_ty = self.typeOf(un_op);
        const ret_ty = ptr_ty.childType(mod);
        const fn_info = mod.typeToFunc(self.dg.decl.ty).?;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            if (Type.fromInterned(fn_info.return_type).isError(mod)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                _ = try self.wip.ret(try o.builder.intValue(try o.errorIntType(), 0));
            } else {
                _ = try self.wip.retVoid();
            }
            return .none;
        }
        if (self.ret_ptr != .none) {
            _ = try self.wip.retVoid();
            return .none;
        }
        const ptr = try self.resolveInst(un_op);
        const abi_ret_ty = try lowerFnRetTy(o, fn_info);
        const alignment = ret_ty.abiAlignment(mod).toLlvm();
        _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, ptr, alignment, ""));
        return .none;
    }

    fn airCVaArg(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const list = try self.resolveInst(ty_op.operand);
        const arg_ty = ty_op.ty.toType();
        const llvm_arg_ty = try o.lowerType(arg_ty);

        return self.wip.vaArg(list, llvm_arg_ty, "");
    }

    fn airCVaCopy(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const src_list = try self.resolveInst(ty_op.operand);
        const va_list_ty = ty_op.ty.toType();
        const llvm_va_list_ty = try o.lowerType(va_list_ty);
        const mod = o.module;

        const result_alignment = va_list_ty.abiAlignment(mod).toLlvm();
        const dest_list = try self.buildAllocaWorkaround(va_list_ty, result_alignment);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_copy, &.{}, &.{ dest_list, src_list }, "");
        return if (isByRef(va_list_ty, mod))
            dest_list
        else
            try self.wip.load(.normal, llvm_va_list_ty, dest_list, result_alignment, "");
    }

    fn airCVaEnd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const src_list = try self.resolveInst(un_op);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_end, &.{}, &.{src_list}, "");
        return .none;
    }

    fn airCVaStart(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const va_list_ty = self.typeOfIndex(inst);
        const llvm_va_list_ty = try o.lowerType(va_list_ty);

        const result_alignment = va_list_ty.abiAlignment(mod).toLlvm();
        const dest_list = try self.buildAllocaWorkaround(va_list_ty, result_alignment);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_start, &.{}, &.{dest_list}, "");
        return if (isByRef(va_list_ty, mod))
            dest_list
        else
            try self.wip.load(.normal, llvm_va_list_ty, dest_list, result_alignment, "");
    }

    fn airCmp(
        self: *FuncGen,
        inst: Air.Inst.Index,
        op: math.CompareOperator,
        fast: Builder.FastMathKind,
    ) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const operand_ty = self.typeOf(bin_op.lhs);

        return self.cmp(fast, op, operand_ty, lhs, rhs);
    }

    fn airCmpVector(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const vec_ty = self.typeOf(extra.lhs);
        const cmp_op = extra.compareOperator();

        return self.cmp(fast, cmp_op, vec_ty, lhs, rhs);
    }

    fn airCmpLtErrorsLen(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const llvm_fn = try o.getCmpLtErrorsLenFunction();
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn cmp(
        self: *FuncGen,
        fast: Builder.FastMathKind,
        op: math.CompareOperator,
        operand_ty: Type,
        lhs: Builder.Value,
        rhs: Builder.Value,
    ) Allocator.Error!Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const scalar_ty = operand_ty.scalarType(mod);
        const int_ty = switch (scalar_ty.zigTypeTag(mod)) {
            .Enum => scalar_ty.intTagType(mod),
            .Int, .Bool, .Pointer, .ErrorSet => scalar_ty,
            .Optional => blk: {
                const payload_ty = operand_ty.optionalChild(mod);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod) or
                    operand_ty.optionalReprIsPayload(mod))
                {
                    break :blk operand_ty;
                }
                // We need to emit instructions to check for equality/inequality
                // of optionals that are not pointers.
                const is_by_ref = isByRef(scalar_ty, mod);
                const opt_llvm_ty = try o.lowerType(scalar_ty);
                const lhs_non_null = try self.optCmpNull(.ne, opt_llvm_ty, lhs, is_by_ref);
                const rhs_non_null = try self.optCmpNull(.ne, opt_llvm_ty, rhs, is_by_ref);
                const llvm_i2 = try o.builder.intType(2);
                const lhs_non_null_i2 = try self.wip.cast(.zext, lhs_non_null, llvm_i2, "");
                const rhs_non_null_i2 = try self.wip.cast(.zext, rhs_non_null, llvm_i2, "");
                const lhs_shifted = try self.wip.bin(.shl, lhs_non_null_i2, try o.builder.intValue(llvm_i2, 1), "");
                const lhs_rhs_ored = try self.wip.bin(.@"or", lhs_shifted, rhs_non_null_i2, "");
                const both_null_block = try self.wip.block(1, "BothNull");
                const mixed_block = try self.wip.block(1, "Mixed");
                const both_pl_block = try self.wip.block(1, "BothNonNull");
                const end_block = try self.wip.block(3, "End");
                var wip_switch = try self.wip.@"switch"(lhs_rhs_ored, mixed_block, 2);
                defer wip_switch.finish(&self.wip);
                try wip_switch.addCase(
                    try o.builder.intConst(llvm_i2, 0b00),
                    both_null_block,
                    &self.wip,
                );
                try wip_switch.addCase(
                    try o.builder.intConst(llvm_i2, 0b11),
                    both_pl_block,
                    &self.wip,
                );

                self.wip.cursor = .{ .block = both_null_block };
                _ = try self.wip.br(end_block);

                self.wip.cursor = .{ .block = mixed_block };
                _ = try self.wip.br(end_block);

                self.wip.cursor = .{ .block = both_pl_block };
                const lhs_payload = try self.optPayloadHandle(opt_llvm_ty, lhs, scalar_ty, true);
                const rhs_payload = try self.optPayloadHandle(opt_llvm_ty, rhs, scalar_ty, true);
                const payload_cmp = try self.cmp(fast, op, payload_ty, lhs_payload, rhs_payload);
                _ = try self.wip.br(end_block);
                const both_pl_block_end = self.wip.cursor.block;

                self.wip.cursor = .{ .block = end_block };
                const llvm_i1_0 = Builder.Value.false;
                const llvm_i1_1 = Builder.Value.true;
                const incoming_values: [3]Builder.Value = .{
                    switch (op) {
                        .eq => llvm_i1_1,
                        .neq => llvm_i1_0,
                        else => unreachable,
                    },
                    switch (op) {
                        .eq => llvm_i1_0,
                        .neq => llvm_i1_1,
                        else => unreachable,
                    },
                    payload_cmp,
                };

                const phi = try self.wip.phi(.i1, "");
                try phi.finish(
                    &incoming_values,
                    &.{ both_null_block, mixed_block, both_pl_block_end },
                    &self.wip,
                );
                return phi.toValue();
            },
            .Float => return self.buildFloatCmp(fast, op, operand_ty, .{ lhs, rhs }),
            else => unreachable,
        };
        const is_signed = int_ty.isSignedInt(mod);
        const cond: Builder.IntegerCondition = switch (op) {
            .eq => .eq,
            .neq => .ne,
            .lt => if (is_signed) .slt else .ult,
            .lte => if (is_signed) .sle else .ule,
            .gt => if (is_signed) .sgt else .ugt,
            .gte => if (is_signed) .sge else .uge,
        };
        return self.wip.icmp(cond, lhs, rhs, "");
    }

    fn airBlock(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Block, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
        const inst_ty = self.typeOfIndex(inst);

        if (inst_ty.isNoReturn(mod)) {
            try self.genBody(body);
            return .none;
        }

        const have_block_result = inst_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod);

        var breaks: BreakList = if (have_block_result) .{ .list = .{} } else .{ .len = 0 };
        defer if (have_block_result) breaks.list.deinit(self.gpa);

        const parent_bb = try self.wip.block(0, "Block");
        try self.blocks.putNoClobber(self.gpa, inst, .{
            .parent_bb = parent_bb,
            .breaks = &breaks,
        });
        defer assert(self.blocks.remove(inst));

        try self.genBody(body);

        self.wip.cursor = .{ .block = parent_bb };

        // Create a phi node only if the block returns a value.
        if (have_block_result) {
            const raw_llvm_ty = try o.lowerType(inst_ty);
            const llvm_ty: Builder.Type = ty: {
                // If the zig tag type is a function, this represents an actual function body; not
                // a pointer to it. LLVM IR allows the call instruction to use function bodies instead
                // of function pointers, however the phi makes it a runtime value and therefore
                // the LLVM type has to be wrapped in a pointer.
                if (inst_ty.zigTypeTag(mod) == .Fn or isByRef(inst_ty, mod)) {
                    break :ty .ptr;
                }
                break :ty raw_llvm_ty;
            };

            parent_bb.ptr(&self.wip).incoming = @intCast(breaks.list.len);
            const phi = try self.wip.phi(llvm_ty, "");
            try phi.finish(breaks.list.items(.val), breaks.list.items(.bb), &self.wip);
            return phi.toValue();
        } else {
            parent_bb.ptr(&self.wip).incoming = @intCast(breaks.len);
            return .none;
        }
    }

    fn airBr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const branch = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
        const block = self.blocks.get(branch.block_inst).?;

        // Add the values to the lists only if the break provides a value.
        const operand_ty = self.typeOf(branch.operand);
        const mod = o.module;
        if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            const val = try self.resolveInst(branch.operand);

            // For the phi node, we need the basic blocks and the values of the
            // break instructions.
            try block.breaks.list.append(self.gpa, .{ .bb = self.wip.cursor.block, .val = val });
        } else block.breaks.len += 1;
        _ = try self.wip.br(block.parent_bb);
        return .none;
    }

    fn airCondBr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const cond = try self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);

        const then_block = try self.wip.block(1, "Then");
        const else_block = try self.wip.block(1, "Else");
        _ = try self.wip.brCond(cond, then_block, else_block);

        self.wip.cursor = .{ .block = then_block };
        try self.genBody(then_body);

        self.wip.cursor = .{ .block = else_block };
        try self.genBody(else_body);

        // No need to reset the insert cursor since this instruction is noreturn.
        return .none;
    }

    fn airTry(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const err_union = try self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.Try, pl_op.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
        const err_union_ty = self.typeOf(pl_op.operand);
        const payload_ty = self.typeOfIndex(inst);
        const can_elide_load = if (isByRef(payload_ty, mod)) self.canElideLoad(body_tail) else false;
        const is_unused = self.liveness.isUnused(inst);
        return lowerTry(self, err_union, body, err_union_ty, false, can_elide_load, is_unused);
    }

    fn airTryPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
        const err_union_ptr = try self.resolveInst(extra.data.ptr);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
        const err_union_ty = self.typeOf(extra.data.ptr).childType(mod);
        const is_unused = self.liveness.isUnused(inst);
        return lowerTry(self, err_union_ptr, body, err_union_ty, true, true, is_unused);
    }

    fn lowerTry(
        fg: *FuncGen,
        err_union: Builder.Value,
        body: []const Air.Inst.Index,
        err_union_ty: Type,
        operand_is_ptr: bool,
        can_elide_load: bool,
        is_unused: bool,
    ) !Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(mod);
        const err_union_llvm_ty = try o.lowerType(err_union_ty);
        const error_type = try o.errorIntType();

        if (!err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            const loaded = loaded: {
                if (!payload_has_bits) {
                    // TODO add alignment to this load
                    break :loaded if (operand_is_ptr)
                        try fg.wip.load(.normal, error_type, err_union, .default, "")
                    else
                        err_union;
                }
                const err_field_index = try errUnionErrorOffset(payload_ty, mod);
                if (operand_is_ptr or isByRef(err_union_ty, mod)) {
                    const err_field_ptr =
                        try fg.wip.gepStruct(err_union_llvm_ty, err_union, err_field_index, "");
                    // TODO add alignment to this load
                    break :loaded try fg.wip.load(
                        .normal,
                        error_type,
                        err_field_ptr,
                        .default,
                        "",
                    );
                }
                break :loaded try fg.wip.extractValue(err_union, &.{err_field_index}, "");
            };
            const zero = try o.builder.intValue(error_type, 0);
            const is_err = try fg.wip.icmp(.ne, loaded, zero, "");

            const return_block = try fg.wip.block(1, "TryRet");
            const continue_block = try fg.wip.block(1, "TryCont");
            _ = try fg.wip.brCond(is_err, return_block, continue_block);

            fg.wip.cursor = .{ .block = return_block };
            try fg.genBody(body);

            fg.wip.cursor = .{ .block = continue_block };
        }
        if (is_unused) return .none;
        if (!payload_has_bits) return if (operand_is_ptr) err_union else .none;
        const offset = try errUnionPayloadOffset(payload_ty, mod);
        if (operand_is_ptr) {
            return fg.wip.gepStruct(err_union_llvm_ty, err_union, offset, "");
        } else if (isByRef(err_union_ty, mod)) {
            const payload_ptr = try fg.wip.gepStruct(err_union_llvm_ty, err_union, offset, "");
            const payload_alignment = payload_ty.abiAlignment(mod).toLlvm();
            if (isByRef(payload_ty, mod)) {
                if (can_elide_load)
                    return payload_ptr;

                return fg.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            const load_ty = err_union_llvm_ty.structFields(&o.builder)[offset];
            return fg.wip.load(.normal, load_ty, payload_ptr, payload_alignment, "");
        }
        return fg.wip.extractValue(err_union, &.{offset}, "");
    }

    fn airSwitchBr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const cond = try self.resolveInst(pl_op.operand);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
        const else_block = try self.wip.block(1, "Default");
        const llvm_usize = try o.lowerType(Type.usize);
        const cond_int = if (cond.typeOfWip(&self.wip).isPointer(&o.builder))
            try self.wip.cast(.ptrtoint, cond, llvm_usize, "")
        else
            cond;

        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;
        var llvm_cases_len: u32 = 0;
        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items: []const Air.Inst.Ref =
                @ptrCast(self.air.extra[case.end..][0..case.data.items_len]);
            const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + case.data.items_len + case_body.len;

            llvm_cases_len += @intCast(items.len);
        }

        var wip_switch = try self.wip.@"switch"(cond_int, else_block, llvm_cases_len);
        defer wip_switch.finish(&self.wip);

        extra_index = switch_br.end;
        case_i = 0;
        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items: []const Air.Inst.Ref =
                @ptrCast(self.air.extra[case.end..][0..case.data.items_len]);
            const case_body: []const Air.Inst.Index = @ptrCast(self.air.extra[case.end + items.len ..][0..case.data.body_len]);
            extra_index = case.end + case.data.items_len + case_body.len;

            const case_block = try self.wip.block(@intCast(items.len), "Case");

            for (items) |item| {
                const llvm_item = (try self.resolveInst(item)).toConst().?;
                const llvm_int_item = if (llvm_item.typeOf(&o.builder).isPointer(&o.builder))
                    try o.builder.castConst(.ptrtoint, llvm_item, llvm_usize)
                else
                    llvm_item;
                try wip_switch.addCase(llvm_int_item, case_block, &self.wip);
            }

            self.wip.cursor = .{ .block = case_block };
            try self.genBody(case_body);
        }

        self.wip.cursor = .{ .block = else_block };
        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra_index..][0..switch_br.data.else_body_len]);
        if (else_body.len != 0) {
            try self.genBody(else_body);
        } else {
            _ = try self.wip.@"unreachable"();
        }

        // No need to reset the insert cursor since this instruction is noreturn.
        return .none;
    }

    fn airLoop(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);
        const loop_block = try self.wip.block(2, "Loop");
        _ = try self.wip.br(loop_block);

        self.wip.cursor = .{ .block = loop_block };
        try self.genBody(body);

        // TODO instead of this logic, change AIR to have the property that
        // every block is guaranteed to end with a noreturn instruction.
        // Then we can simply rely on the fact that a repeat or break instruction
        // would have been emitted already. Also the main loop in genBody can
        // be while(true) instead of for(body), which will eliminate 1 branch on
        // a hot path.
        if (body.len == 0 or !self.typeOfIndex(body[body.len - 1]).isNoReturn(mod)) {
            _ = try self.wip.br(loop_block);
        }
        return .none;
    }

    fn airArrayToSlice(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const array_ty = operand_ty.childType(mod);
        const llvm_usize = try o.lowerType(Type.usize);
        const len = try o.builder.intValue(llvm_usize, array_ty.arrayLen(mod));
        const slice_llvm_ty = try o.lowerType(self.typeOfIndex(inst));
        const operand = try self.resolveInst(ty_op.operand);
        if (!array_ty.hasRuntimeBitsIgnoreComptime(mod))
            return self.wip.buildAggregate(slice_llvm_ty, &.{ operand, len }, "");
        const ptr = try self.wip.gep(.inbounds, try o.lowerType(array_ty), operand, &.{
            try o.builder.intValue(llvm_usize, 0), try o.builder.intValue(llvm_usize, 0),
        }, "");
        return self.wip.buildAggregate(slice_llvm_ty, &.{ ptr, len }, "");
    }

    fn airFloatFromInt(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

        const workaround_operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_scalar_ty = operand_ty.scalarType(mod);
        const is_signed_int = operand_scalar_ty.isSignedInt(mod);

        const operand = o: {
            // Work around LLVM bug. See https://github.com/ziglang/zig/issues/17381.
            const bit_size = operand_scalar_ty.bitSize(mod);
            for ([_]u8{ 8, 16, 32, 64, 128 }) |b| {
                if (bit_size < b) {
                    break :o try self.wip.cast(
                        if (is_signed_int) .sext else .zext,
                        workaround_operand,
                        try o.builder.intType(b),
                        "",
                    );
                } else if (bit_size == b) {
                    break :o workaround_operand;
                }
            }
            break :o workaround_operand;
        };

        const dest_ty = self.typeOfIndex(inst);
        const dest_scalar_ty = dest_ty.scalarType(mod);
        const dest_llvm_ty = try o.lowerType(dest_ty);
        const target = mod.getTarget();

        if (intrinsicsAllowed(dest_scalar_ty, target)) return self.wip.conv(
            if (is_signed_int) .signed else .unsigned,
            operand,
            dest_llvm_ty,
            "",
        );

        const rt_int_bits = compilerRtIntBits(@intCast(operand_scalar_ty.bitSize(mod)));
        const rt_int_ty = try o.builder.intType(rt_int_bits);
        var extended = try self.wip.conv(
            if (is_signed_int) .signed else .unsigned,
            operand,
            rt_int_ty,
            "",
        );
        const dest_bits = dest_scalar_ty.floatBits(target);
        const compiler_rt_operand_abbrev = compilerRtIntAbbrev(rt_int_bits);
        const compiler_rt_dest_abbrev = compilerRtFloatAbbrev(dest_bits);
        const sign_prefix = if (is_signed_int) "" else "un";
        const fn_name = try o.builder.fmt("__float{s}{s}i{s}f", .{
            sign_prefix,
            compiler_rt_operand_abbrev,
            compiler_rt_dest_abbrev,
        });

        var param_type = rt_int_ty;
        if (rt_int_bits == 128 and (target.os.tag == .windows and target.cpu.arch == .x86_64)) {
            // On Windows x86-64, "ti" functions must use Vector(2, u64) instead of the standard
            // i128 calling convention to adhere to the ABI that LLVM expects compiler-rt to have.
            param_type = try o.builder.vectorType(.normal, 2, .i64);
            extended = try self.wip.cast(.bitcast, extended, param_type, "");
        }

        const libc_fn = try self.getLibcFunction(fn_name, &.{param_type}, dest_llvm_ty);
        return self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &.{extended},
            "",
        );
    }

    fn airIntFromFloat(
        self: *FuncGen,
        inst: Air.Inst.Index,
        fast: Builder.FastMathKind,
    ) !Builder.Value {
        _ = fast;

        const o = self.dg.object;
        const mod = o.module;
        const target = mod.getTarget();
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_scalar_ty = operand_ty.scalarType(mod);

        const dest_ty = self.typeOfIndex(inst);
        const dest_scalar_ty = dest_ty.scalarType(mod);
        const dest_llvm_ty = try o.lowerType(dest_ty);

        if (intrinsicsAllowed(operand_scalar_ty, target)) {
            // TODO set fast math flag
            return self.wip.conv(
                if (dest_scalar_ty.isSignedInt(mod)) .signed else .unsigned,
                operand,
                dest_llvm_ty,
                "",
            );
        }

        const rt_int_bits = compilerRtIntBits(@intCast(dest_scalar_ty.bitSize(mod)));
        const ret_ty = try o.builder.intType(rt_int_bits);
        const libc_ret_ty = if (rt_int_bits == 128 and (target.os.tag == .windows and target.cpu.arch == .x86_64)) b: {
            // On Windows x86-64, "ti" functions must use Vector(2, u64) instead of the standard
            // i128 calling convention to adhere to the ABI that LLVM expects compiler-rt to have.
            break :b try o.builder.vectorType(.normal, 2, .i64);
        } else ret_ty;

        const operand_bits = operand_scalar_ty.floatBits(target);
        const compiler_rt_operand_abbrev = compilerRtFloatAbbrev(operand_bits);

        const compiler_rt_dest_abbrev = compilerRtIntAbbrev(rt_int_bits);
        const sign_prefix = if (dest_scalar_ty.isSignedInt(mod)) "" else "uns";

        const fn_name = try o.builder.fmt("__fix{s}{s}f{s}i", .{
            sign_prefix,
            compiler_rt_operand_abbrev,
            compiler_rt_dest_abbrev,
        });

        const operand_llvm_ty = try o.lowerType(operand_ty);
        const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, libc_ret_ty);
        var result = try self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &.{operand},
            "",
        );

        if (libc_ret_ty != ret_ty) result = try self.wip.cast(.bitcast, result, ret_ty, "");
        if (ret_ty != dest_llvm_ty) result = try self.wip.cast(.trunc, result, dest_llvm_ty, "");
        return result;
    }

    fn sliceOrArrayPtr(fg: *FuncGen, ptr: Builder.Value, ty: Type) Allocator.Error!Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        return if (ty.isSlice(mod)) fg.wip.extractValue(ptr, &.{0}, "") else ptr;
    }

    fn sliceOrArrayLenInBytes(fg: *FuncGen, ptr: Builder.Value, ty: Type) Allocator.Error!Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        const llvm_usize = try o.lowerType(Type.usize);
        switch (ty.ptrSize(mod)) {
            .Slice => {
                const len = try fg.wip.extractValue(ptr, &.{1}, "");
                const elem_ty = ty.childType(mod);
                const abi_size = elem_ty.abiSize(mod);
                if (abi_size == 1) return len;
                const abi_size_llvm_val = try o.builder.intValue(llvm_usize, abi_size);
                return fg.wip.bin(.@"mul nuw", len, abi_size_llvm_val, "");
            },
            .One => {
                const array_ty = ty.childType(mod);
                const elem_ty = array_ty.childType(mod);
                const abi_size = elem_ty.abiSize(mod);
                return o.builder.intValue(llvm_usize, array_ty.arrayLen(mod) * abi_size);
            },
            .Many, .C => unreachable,
        }
    }

    fn airSliceField(self: *FuncGen, inst: Air.Inst.Index, index: u32) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        return self.wip.extractValue(operand, &.{index}, "");
    }

    fn airPtrSliceFieldPtr(self: *FuncGen, inst: Air.Inst.Index, index: c_uint) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const slice_ptr = try self.resolveInst(ty_op.operand);
        const slice_ptr_ty = self.typeOf(ty_op.operand);
        const slice_llvm_ty = try o.lowerPtrElemTy(slice_ptr_ty.childType(mod));

        return self.wip.gepStruct(slice_llvm_ty, slice_ptr, index, "");
    }

    fn airSliceElemVal(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const slice_ty = self.typeOf(bin_op.lhs);
        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        const elem_ty = slice_ty.childType(mod);
        const llvm_elem_ty = try o.lowerPtrElemTy(elem_ty);
        const base_ptr = try self.wip.extractValue(slice, &.{0}, "");
        const ptr = try self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, &.{index}, "");
        if (isByRef(elem_ty, mod)) {
            if (self.canElideLoad(body_tail))
                return ptr;

            const elem_alignment = elem_ty.abiAlignment(mod).toLlvm();
            return self.loadByRef(ptr, elem_ty, elem_alignment, .normal);
        }

        return self.load(ptr, slice_ty);
    }

    fn airSliceElemPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const slice_ty = self.typeOf(bin_op.lhs);

        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(slice_ty.childType(mod));
        const base_ptr = try self.wip.extractValue(slice, &.{0}, "");
        return self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, &.{index}, "");
    }

    fn airArrayElemVal(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];

        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const array_ty = self.typeOf(bin_op.lhs);
        const array_llvm_val = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const array_llvm_ty = try o.lowerType(array_ty);
        const elem_ty = array_ty.childType(mod);
        if (isByRef(array_ty, mod)) {
            const indices: [2]Builder.Value = .{
                try o.builder.intValue(try o.lowerType(Type.usize), 0), rhs,
            };
            if (isByRef(elem_ty, mod)) {
                const elem_ptr =
                    try self.wip.gep(.inbounds, array_llvm_ty, array_llvm_val, &indices, "");
                if (canElideLoad(self, body_tail)) return elem_ptr;
                const elem_alignment = elem_ty.abiAlignment(mod).toLlvm();
                return self.loadByRef(elem_ptr, elem_ty, elem_alignment, .normal);
            } else {
                if (bin_op.lhs.toIndex()) |lhs_index| {
                    if (self.air.instructions.items(.tag)[@intFromEnum(lhs_index)] == .load) {
                        const load_data = self.air.instructions.items(.data)[@intFromEnum(lhs_index)];
                        const load_ptr = load_data.ty_op.operand;
                        if (load_ptr.toIndex()) |load_ptr_index| {
                            const load_ptr_tag = self.air.instructions.items(.tag)[@intFromEnum(load_ptr_index)];
                            switch (load_ptr_tag) {
                                .struct_field_ptr,
                                .struct_field_ptr_index_0,
                                .struct_field_ptr_index_1,
                                .struct_field_ptr_index_2,
                                .struct_field_ptr_index_3,
                                => {
                                    const load_ptr_inst = try self.resolveInst(load_ptr);
                                    const gep = try self.wip.gep(
                                        .inbounds,
                                        array_llvm_ty,
                                        load_ptr_inst,
                                        &indices,
                                        "",
                                    );
                                    return self.loadTruncate(.normal, elem_ty, gep, .default);
                                },
                                else => {},
                            }
                        }
                    }
                }
                const elem_ptr =
                    try self.wip.gep(.inbounds, array_llvm_ty, array_llvm_val, &indices, "");
                return self.loadTruncate(.normal, elem_ty, elem_ptr, .default);
            }
        }

        // This branch can be reached for vectors, which are always by-value.
        return self.wip.extractElement(array_llvm_val, rhs, "");
    }

    fn airPtrElemVal(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(mod);
        const llvm_elem_ty = try o.lowerPtrElemTy(elem_ty);
        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        // TODO: when we go fully opaque pointers in LLVM 16 we can remove this branch
        const ptr = try self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, if (ptr_ty.isSinglePointer(mod))
            // If this is a single-item pointer to an array, we need another index in the GEP.
            &.{ try o.builder.intValue(try o.lowerType(Type.usize), 0), rhs }
        else
            &.{rhs}, "");
        if (isByRef(elem_ty, mod)) {
            if (self.canElideLoad(body_tail)) return ptr;
            const elem_alignment = elem_ty.abiAlignment(mod).toLlvm();
            return self.loadByRef(ptr, elem_ty, elem_alignment, .normal);
        }

        return self.load(ptr, ptr_ty);
    }

    fn airPtrElemPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(mod);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) return self.resolveInst(bin_op.lhs);

        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const elem_ptr = ty_pl.ty.toType();
        if (elem_ptr.ptrInfo(mod).flags.vector_index != .none) return base_ptr;

        const llvm_elem_ty = try o.lowerPtrElemTy(elem_ty);
        return self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, if (ptr_ty.isSinglePointer(mod))
            // If this is a single-item pointer to an array, we need another index in the GEP.
            &.{ try o.builder.intValue(try o.lowerType(Type.usize), 0), rhs }
        else
            &.{rhs}, "");
    }

    fn airStructFieldPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ptr = try self.resolveInst(struct_field.struct_operand);
        const struct_ptr_ty = self.typeOf(struct_field.struct_operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, struct_field.field_index);
    }

    fn airStructFieldPtrIndex(
        self: *FuncGen,
        inst: Air.Inst.Index,
        field_index: u32,
    ) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const struct_ptr = try self.resolveInst(ty_op.operand);
        const struct_ptr_ty = self.typeOf(ty_op.operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, field_index);
    }

    fn airStructFieldVal(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ty = self.typeOf(struct_field.struct_operand);
        const struct_llvm_val = try self.resolveInst(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = struct_ty.structFieldType(field_index, mod);
        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) return .none;

        if (!isByRef(struct_ty, mod)) {
            assert(!isByRef(field_ty, mod));
            switch (struct_ty.zigTypeTag(mod)) {
                .Struct => switch (struct_ty.containerLayout(mod)) {
                    .Packed => {
                        const struct_type = mod.typeToStruct(struct_ty).?;
                        const bit_offset = mod.structPackedFieldBitOffset(struct_type, field_index);
                        const containing_int = struct_llvm_val;
                        const shift_amt =
                            try o.builder.intValue(containing_int.typeOfWip(&self.wip), bit_offset);
                        const shifted_value = try self.wip.bin(.lshr, containing_int, shift_amt, "");
                        const elem_llvm_ty = try o.lowerType(field_ty);
                        if (field_ty.zigTypeTag(mod) == .Float or field_ty.zigTypeTag(mod) == .Vector) {
                            const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(mod)));
                            const truncated_int =
                                try self.wip.cast(.trunc, shifted_value, same_size_int, "");
                            return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
                        } else if (field_ty.isPtrAtRuntime(mod)) {
                            const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(mod)));
                            const truncated_int =
                                try self.wip.cast(.trunc, shifted_value, same_size_int, "");
                            return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
                        }
                        return self.wip.cast(.trunc, shifted_value, elem_llvm_ty, "");
                    },
                    else => {
                        const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
                        return self.wip.extractValue(struct_llvm_val, &.{llvm_field_index}, "");
                    },
                },
                .Union => {
                    assert(struct_ty.containerLayout(mod) == .Packed);
                    const containing_int = struct_llvm_val;
                    const elem_llvm_ty = try o.lowerType(field_ty);
                    if (field_ty.zigTypeTag(mod) == .Float or field_ty.zigTypeTag(mod) == .Vector) {
                        const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(mod)));
                        const truncated_int =
                            try self.wip.cast(.trunc, containing_int, same_size_int, "");
                        return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
                    } else if (field_ty.isPtrAtRuntime(mod)) {
                        const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(mod)));
                        const truncated_int =
                            try self.wip.cast(.trunc, containing_int, same_size_int, "");
                        return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
                    }
                    return self.wip.cast(.trunc, containing_int, elem_llvm_ty, "");
                },
                else => unreachable,
            }
        }

        switch (struct_ty.zigTypeTag(mod)) {
            .Struct => {
                const layout = struct_ty.containerLayout(mod);
                assert(layout != .Packed);
                const struct_llvm_ty = try o.lowerType(struct_ty);
                const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
                const field_ptr =
                    try self.wip.gepStruct(struct_llvm_ty, struct_llvm_val, llvm_field_index, "");
                const alignment = struct_ty.structFieldAlign(field_index, mod);
                const field_ptr_ty = try mod.ptrType(.{
                    .child = field_ty.toIntern(),
                    .flags = .{ .alignment = alignment },
                });
                if (isByRef(field_ty, mod)) {
                    if (canElideLoad(self, body_tail))
                        return field_ptr;

                    assert(alignment != .none);
                    const field_alignment = alignment.toLlvm();
                    return self.loadByRef(field_ptr, field_ty, field_alignment, .normal);
                } else {
                    return self.load(field_ptr, field_ptr_ty);
                }
            },
            .Union => {
                const union_llvm_ty = try o.lowerType(struct_ty);
                const layout = struct_ty.unionGetLayout(mod);
                const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
                const field_ptr =
                    try self.wip.gepStruct(union_llvm_ty, struct_llvm_val, payload_index, "");
                const payload_alignment = layout.payload_align.toLlvm();
                if (isByRef(field_ty, mod)) {
                    if (canElideLoad(self, body_tail)) return field_ptr;
                    return self.loadByRef(field_ptr, field_ty, payload_alignment, .normal);
                } else {
                    return self.loadTruncate(.normal, field_ty, field_ptr, payload_alignment);
                }
            },
            else => unreachable,
        }
    }

    fn airFieldParentPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        const field_ptr = try self.resolveInst(extra.field_ptr);

        const parent_ty = ty_pl.ty.toType().childType(mod);
        const field_offset = parent_ty.structFieldOffset(extra.field_index, mod);
        if (field_offset == 0) return field_ptr;

        const res_ty = try o.lowerType(ty_pl.ty.toType());
        const llvm_usize = try o.lowerType(Type.usize);

        const field_ptr_int = try self.wip.cast(.ptrtoint, field_ptr, llvm_usize, "");
        const base_ptr_int = try self.wip.bin(
            .@"sub nuw",
            field_ptr_int,
            try o.builder.intValue(llvm_usize, field_offset),
            "",
        );
        return self.wip.cast(.inttoptr, base_ptr_int, res_ty, "");
    }

    fn airNot(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);

        return self.wip.not(operand, "");
    }

    fn airUnreach(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        _ = try self.wip.@"unreachable"();
        return .none;
    }

    fn airDbgStmt(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const di_scope = self.di_scope orelse return .none;
        const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
        self.prev_dbg_line = @intCast(self.base_line + dbg_stmt.line + 1);
        self.prev_dbg_column = @intCast(dbg_stmt.column + 1);
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        self.wip.llvm.builder.setCurrentDebugLocation(
            self.prev_dbg_line,
            self.prev_dbg_column,
            di_scope,
            inlined_at,
        );
        return .none;
    }

    fn airDbgInlineBegin(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const dib = o.di_builder orelse return .none;
        const ty_fn = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_fn;

        const zcu = o.module;
        const func = zcu.funcInfo(ty_fn.func);
        const decl_index = func.owner_decl;
        const decl = zcu.declPtr(decl_index);
        const namespace = zcu.namespacePtr(decl.src_namespace);
        const owner_mod = namespace.file_scope.mod;
        const di_file = try o.getDIFile(self.gpa, zcu.namespacePtr(decl.src_namespace).file_scope);
        self.di_file = di_file;
        const line_number = decl.src_line + 1;
        const cur_debug_location = self.wip.llvm.builder.getCurrentDebugLocation2();

        try self.dbg_inlined.append(self.gpa, .{
            .loc = @ptrCast(cur_debug_location),
            .scope = self.di_scope.?,
            .base_line = self.base_line,
        });

        const fqn = try decl.getFullyQualifiedName(zcu);

        const is_internal_linkage = !zcu.decl_exports.contains(decl_index);
        const fn_ty = try zcu.funcType(.{
            .param_types = &.{},
            .return_type = .void_type,
        });
        const fn_di_ty = try o.lowerDebugType(fn_ty, .full);
        const subprogram = dib.createFunction(
            di_file.toScope(),
            zcu.intern_pool.stringToSlice(decl.name),
            zcu.intern_pool.stringToSlice(fqn),
            di_file,
            line_number,
            fn_di_ty,
            is_internal_linkage,
            true, // is definition
            line_number + func.lbrace_line, // scope line
            llvm.DIFlags.StaticMember,
            owner_mod.optimize_mode != .Debug,
            null, // decl_subprogram
        );

        const lexical_block = dib.createLexicalBlock(subprogram.toScope(), di_file, line_number, 1);
        self.di_scope = lexical_block.toScope();
        self.base_line = decl.src_line;
        return .none;
    }

    fn airDbgInlineEnd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        if (o.di_builder == null) return .none;
        const ty_fn = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_fn;

        const mod = o.module;
        const decl = mod.funcOwnerDeclPtr(ty_fn.func);
        const di_file = try o.getDIFile(self.gpa, mod.namespacePtr(decl.src_namespace).file_scope);
        self.di_file = di_file;
        const old = self.dbg_inlined.pop();
        self.di_scope = old.scope;
        self.base_line = old.base_line;
        return .none;
    }

    fn airDbgBlockBegin(self: *FuncGen) !Builder.Value {
        const o = self.dg.object;
        const dib = o.di_builder orelse return .none;
        const old_scope = self.di_scope.?;
        try self.dbg_block_stack.append(self.gpa, old_scope);
        const lexical_block = dib.createLexicalBlock(old_scope, self.di_file.?, self.prev_dbg_line, self.prev_dbg_column);
        self.di_scope = lexical_block.toScope();
        return .none;
    }

    fn airDbgBlockEnd(self: *FuncGen) !Builder.Value {
        const o = self.dg.object;
        if (o.di_builder == null) return .none;
        self.di_scope = self.dbg_block_stack.pop();
        return .none;
    }

    fn airDbgVarPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const dib = o.di_builder orelse return .none;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);
        const ptr_ty = self.typeOf(pl_op.operand);

        const di_local_var = dib.createAutoVariable(
            self.di_scope.?,
            name.ptr,
            self.di_file.?,
            self.prev_dbg_line,
            try o.lowerDebugType(ptr_ty.childType(mod), .full),
            true, // always preserve
            0, // flags
        );
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        const debug_loc = llvm.getDebugLoc(self.prev_dbg_line, self.prev_dbg_column, self.di_scope.?, inlined_at);
        const insert_block = self.wip.cursor.block.toLlvm(&self.wip);
        _ = dib.insertDeclareAtEnd(operand.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
        return .none;
    }

    fn airDbgVarVal(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const dib = o.di_builder orelse return .none;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const operand_ty = self.typeOf(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);

        if (needDbgVarWorkaround(o)) return .none;

        const di_local_var = dib.createAutoVariable(
            self.di_scope.?,
            name.ptr,
            self.di_file.?,
            self.prev_dbg_line,
            try o.lowerDebugType(operand_ty, .full),
            true, // always preserve
            0, // flags
        );
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        const debug_loc = llvm.getDebugLoc(self.prev_dbg_line, self.prev_dbg_column, self.di_scope.?, inlined_at);
        const insert_block = self.wip.cursor.block.toLlvm(&self.wip);
        const zcu = o.module;
        const owner_mod = self.dg.ownerModule();
        if (isByRef(operand_ty, zcu)) {
            _ = dib.insertDeclareAtEnd(operand.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
        } else if (owner_mod.optimize_mode == .Debug) {
            const alignment = operand_ty.abiAlignment(zcu).toLlvm();
            const alloca = try self.buildAlloca(operand.typeOfWip(&self.wip), alignment);
            _ = try self.wip.store(.normal, operand, alloca, alignment);
            _ = dib.insertDeclareAtEnd(alloca.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
        } else {
            _ = dib.insertDbgValueIntrinsicAtEnd(operand.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
        }
        return .none;
    }

    fn airAssembly(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        // Eventually, the Zig compiler needs to be reworked to have inline
        // assembly go through the same parsing code regardless of backend, and
        // have LLVM-flavored inline assembly be *output* from that assembler.
        // We don't have such an assembler implemented yet though. For now,
        // this implementation feeds the inline assembly code directly to LLVM.

        const o = self.dg.object;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);
        const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
        const clobbers_len: u31 = @truncate(extra.data.flags);
        var extra_i: usize = extra.end;

        const outputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]);
        extra_i += outputs.len;
        const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]);
        extra_i += inputs.len;

        var llvm_constraints: std.ArrayListUnmanaged(u8) = .{};
        defer llvm_constraints.deinit(self.gpa);

        var arena_allocator = std.heap.ArenaAllocator.init(self.gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        // The exact number of return / parameter values depends on which output values
        // are passed by reference as indirect outputs (determined below).
        const max_return_count = outputs.len;
        const llvm_ret_types = try arena.alloc(Builder.Type, max_return_count);
        const llvm_ret_indirect = try arena.alloc(bool, max_return_count);
        const llvm_rw_vals = try arena.alloc(Builder.Value, max_return_count);

        const max_param_count = max_return_count + inputs.len + outputs.len;
        const llvm_param_types = try arena.alloc(Builder.Type, max_param_count);
        const llvm_param_values = try arena.alloc(Builder.Value, max_param_count);
        // This stores whether we need to add an elementtype attribute and
        // if so, the element type itself.
        const llvm_param_attrs = try arena.alloc(Builder.Type, max_param_count);
        const mod = o.module;
        const target = mod.getTarget();

        var llvm_ret_i: usize = 0;
        var llvm_param_i: usize = 0;
        var total_i: u16 = 0;

        var name_map: std.StringArrayHashMapUnmanaged(u16) = .{};
        try name_map.ensureUnusedCapacity(arena, max_param_count);

        var rw_extra_i = extra_i;
        for (outputs, llvm_ret_indirect, llvm_rw_vals) |output, *is_indirect, *llvm_rw_val| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            try llvm_constraints.ensureUnusedCapacity(self.gpa, constraint.len + 3);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendAssumeCapacity('=');

            if (output != .none) {
                const output_inst = try self.resolveInst(output);
                const output_ty = self.typeOf(output);
                assert(output_ty.zigTypeTag(mod) == .Pointer);
                const elem_llvm_ty = try o.lowerPtrElemTy(output_ty.childType(mod));

                switch (constraint[0]) {
                    '=' => {},
                    '+' => llvm_rw_val.* = output_inst,
                    else => return self.todo("unsupported output constraint on output type '{c}'", .{
                        constraint[0],
                    }),
                }

                // Pass any non-return outputs indirectly, if the constraint accepts a memory location
                is_indirect.* = constraintAllowsMemory(constraint);
                if (is_indirect.*) {
                    // Pass the result by reference as an indirect output (e.g. "=*m")
                    llvm_constraints.appendAssumeCapacity('*');

                    llvm_param_values[llvm_param_i] = output_inst;
                    llvm_param_types[llvm_param_i] = output_inst.typeOfWip(&self.wip);
                    llvm_param_attrs[llvm_param_i] = elem_llvm_ty;
                    llvm_param_i += 1;
                } else {
                    // Pass the result directly (e.g. "=r")
                    llvm_ret_types[llvm_ret_i] = elem_llvm_ty;
                    llvm_ret_i += 1;
                }
            } else {
                switch (constraint[0]) {
                    '=' => {},
                    else => return self.todo("unsupported output constraint on result type '{s}'", .{
                        constraint,
                    }),
                }

                is_indirect.* = false;

                const ret_ty = self.typeOfIndex(inst);
                llvm_ret_types[llvm_ret_i] = try o.lowerType(ret_ty);
                llvm_ret_i += 1;
            }

            // LLVM uses commas internally to separate different constraints,
            // alternative constraints are achieved with pipes.
            // We still allow the user to use commas in a way that is similar
            // to GCC's inline assembly.
            // http://llvm.org/docs/LangRef.html#constraint-codes
            for (constraint[1..]) |byte| {
                switch (byte) {
                    ',' => llvm_constraints.appendAssumeCapacity('|'),
                    '*' => {}, // Indirect outputs are handled above
                    else => llvm_constraints.appendAssumeCapacity(byte),
                }
            }

            if (!std.mem.eql(u8, name, "_")) {
                const gop = name_map.getOrPutAssumeCapacity(name);
                if (gop.found_existing) return self.todo("duplicate asm output name '{s}'", .{name});
                gop.value_ptr.* = total_i;
            }
            total_i += 1;
        }

        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const arg_llvm_value = try self.resolveInst(input);
            const arg_ty = self.typeOf(input);
            const is_by_ref = isByRef(arg_ty, mod);
            if (is_by_ref) {
                if (constraintAllowsMemory(constraint)) {
                    llvm_param_values[llvm_param_i] = arg_llvm_value;
                    llvm_param_types[llvm_param_i] = arg_llvm_value.typeOfWip(&self.wip);
                } else {
                    const alignment = arg_ty.abiAlignment(mod).toLlvm();
                    const arg_llvm_ty = try o.lowerType(arg_ty);
                    const load_inst =
                        try self.wip.load(.normal, arg_llvm_ty, arg_llvm_value, alignment, "");
                    llvm_param_values[llvm_param_i] = load_inst;
                    llvm_param_types[llvm_param_i] = arg_llvm_ty;
                }
            } else {
                if (constraintAllowsRegister(constraint)) {
                    llvm_param_values[llvm_param_i] = arg_llvm_value;
                    llvm_param_types[llvm_param_i] = arg_llvm_value.typeOfWip(&self.wip);
                } else {
                    const alignment = arg_ty.abiAlignment(mod).toLlvm();
                    const arg_ptr = try self.buildAlloca(arg_llvm_value.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, arg_llvm_value, arg_ptr, alignment);
                    llvm_param_values[llvm_param_i] = arg_ptr;
                    llvm_param_types[llvm_param_i] = arg_ptr.typeOfWip(&self.wip);
                }
            }

            try llvm_constraints.ensureUnusedCapacity(self.gpa, constraint.len + 1);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            for (constraint) |byte| {
                llvm_constraints.appendAssumeCapacity(switch (byte) {
                    ',' => '|',
                    else => byte,
                });
            }

            if (!std.mem.eql(u8, name, "_")) {
                const gop = name_map.getOrPutAssumeCapacity(name);
                if (gop.found_existing) return self.todo("duplicate asm input name '{s}'", .{name});
                gop.value_ptr.* = total_i;
            }

            // In the case of indirect inputs, LLVM requires the callsite to have
            // an elementtype(<ty>) attribute.
            llvm_param_attrs[llvm_param_i] = if (constraint[0] == '*')
                try o.lowerPtrElemTy(if (is_by_ref) arg_ty else arg_ty.childType(mod))
            else
                .none;

            llvm_param_i += 1;
            total_i += 1;
        }

        for (outputs, llvm_ret_indirect, llvm_rw_vals, 0..) |output, is_indirect, llvm_rw_val, output_index| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[rw_extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[rw_extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            rw_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint[0] != '+') continue;

            const rw_ty = self.typeOf(output);
            const llvm_elem_ty = try o.lowerPtrElemTy(rw_ty.childType(mod));
            if (is_indirect) {
                llvm_param_values[llvm_param_i] = llvm_rw_val;
                llvm_param_types[llvm_param_i] = llvm_rw_val.typeOfWip(&self.wip);
            } else {
                const alignment = rw_ty.abiAlignment(mod).toLlvm();
                const loaded = try self.wip.load(.normal, llvm_elem_ty, llvm_rw_val, alignment, "");
                llvm_param_values[llvm_param_i] = loaded;
                llvm_param_types[llvm_param_i] = llvm_elem_ty;
            }

            try llvm_constraints.writer(self.gpa).print(",{d}", .{output_index});

            // In the case of indirect inputs, LLVM requires the callsite to have
            // an elementtype(<ty>) attribute.
            llvm_param_attrs[llvm_param_i] = if (is_indirect) llvm_elem_ty else .none;

            llvm_param_i += 1;
            total_i += 1;
        }

        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;

                try llvm_constraints.ensureUnusedCapacity(self.gpa, clobber.len + 4);
                if (total_i != 0) {
                    llvm_constraints.appendAssumeCapacity(',');
                }
                llvm_constraints.appendSliceAssumeCapacity("~{");
                llvm_constraints.appendSliceAssumeCapacity(clobber);
                llvm_constraints.appendSliceAssumeCapacity("}");

                total_i += 1;
            }
        }

        // We have finished scanning through all inputs/outputs, so the number of
        // parameters and return values is known.
        const param_count = llvm_param_i;
        const return_count = llvm_ret_i;

        // For some targets, Clang unconditionally adds some clobbers to all inline assembly.
        // While this is probably not strictly necessary, if we don't follow Clang's lead
        // here then we may risk tripping LLVM bugs since anything not used by Clang tends
        // to be buggy and regress often.
        switch (target.cpu.arch) {
            .x86_64, .x86 => {
                if (total_i != 0) try llvm_constraints.append(self.gpa, ',');
                try llvm_constraints.appendSlice(self.gpa, "~{dirflag},~{fpsr},~{flags}");
                total_i += 3;
            },
            .mips, .mipsel, .mips64, .mips64el => {
                if (total_i != 0) try llvm_constraints.append(self.gpa, ',');
                try llvm_constraints.appendSlice(self.gpa, "~{$1}");
                total_i += 1;
            },
            else => {},
        }

        const asm_source = std.mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];

        // hackety hacks until stage2 has proper inline asm in the frontend.
        var rendered_template = std.ArrayList(u8).init(self.gpa);
        defer rendered_template.deinit();

        const State = enum { start, percent, input, modifier };

        var state: State = .start;

        var name_start: usize = undefined;
        var modifier_start: usize = undefined;
        for (asm_source, 0..) |byte, i| {
            switch (state) {
                .start => switch (byte) {
                    '%' => state = .percent,
                    '$' => try rendered_template.appendSlice("$$"),
                    else => try rendered_template.append(byte),
                },
                .percent => switch (byte) {
                    '%' => {
                        try rendered_template.append('%');
                        state = .start;
                    },
                    '[' => {
                        try rendered_template.append('$');
                        try rendered_template.append('{');
                        name_start = i + 1;
                        state = .input;
                    },
                    else => {
                        try rendered_template.append('%');
                        try rendered_template.append(byte);
                        state = .start;
                    },
                },
                .input => switch (byte) {
                    ']', ':' => {
                        const name = asm_source[name_start..i];

                        const index = name_map.get(name) orelse {
                            // we should validate the assembly in Sema; by now it is too late
                            return self.todo("unknown input or output name: '{s}'", .{name});
                        };
                        try rendered_template.writer().print("{d}", .{index});
                        if (byte == ':') {
                            try rendered_template.append(':');
                            modifier_start = i + 1;
                            state = .modifier;
                        } else {
                            try rendered_template.append('}');
                            state = .start;
                        }
                    },
                    else => {},
                },
                .modifier => switch (byte) {
                    ']' => {
                        try rendered_template.appendSlice(asm_source[modifier_start..i]);
                        try rendered_template.append('}');
                        state = .start;
                    },
                    else => {},
                },
            }
        }

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        for (llvm_param_attrs[0..param_count], 0..) |llvm_elem_ty, i| if (llvm_elem_ty != .none)
            try attributes.addParamAttr(i, .{ .elementtype = llvm_elem_ty }, &o.builder);

        const ret_llvm_ty = switch (return_count) {
            0 => .void,
            1 => llvm_ret_types[0],
            else => try o.builder.structType(.normal, llvm_ret_types),
        };
        const llvm_fn_ty = try o.builder.fnType(ret_llvm_ty, llvm_param_types[0..param_count], .normal);
        const call = try self.wip.callAsm(
            try attributes.finish(&o.builder),
            llvm_fn_ty,
            .{ .sideeffect = is_volatile },
            try o.builder.string(rendered_template.items),
            try o.builder.string(llvm_constraints.items),
            llvm_param_values[0..param_count],
            "",
        );

        var ret_val = call;
        llvm_ret_i = 0;
        for (outputs, 0..) |output, i| {
            if (llvm_ret_indirect[i]) continue;

            const output_value = if (return_count > 1)
                try self.wip.extractValue(call, &[_]u32{@intCast(llvm_ret_i)}, "")
            else
                call;

            if (output != .none) {
                const output_ptr = try self.resolveInst(output);
                const output_ptr_ty = self.typeOf(output);

                const alignment = output_ptr_ty.ptrAlignment(mod).toLlvm();
                _ = try self.wip.store(.normal, output_value, output_ptr, alignment);
            } else {
                ret_val = output_value;
            }
            llvm_ret_i += 1;
        }

        return ret_val;
    }

    fn airIsNonNull(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
        cond: Builder.IntegerCondition,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);
        const optional_ty = if (operand_is_ptr) operand_ty.childType(mod) else operand_ty;
        const optional_llvm_ty = try o.lowerType(optional_ty);
        const payload_ty = optional_ty.optionalChild(mod);
        if (optional_ty.optionalReprIsPayload(mod)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(.normal, optional_llvm_ty, operand, .default, "")
            else
                operand;
            if (payload_ty.isSlice(mod)) {
                const slice_ptr = try self.wip.extractValue(loaded, &.{0}, "");
                const ptr_ty = try o.builder.ptrType(toLlvmAddressSpace(
                    payload_ty.ptrAddressSpace(mod),
                    mod.getTarget(),
                ));
                return self.wip.icmp(cond, slice_ptr, try o.builder.nullValue(ptr_ty), "");
            }
            return self.wip.icmp(cond, loaded, try o.builder.zeroInitValue(optional_llvm_ty), "");
        }

        comptime assert(optional_layout_version == 3);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(.normal, optional_llvm_ty, operand, .default, "")
            else
                operand;
            return self.wip.icmp(cond, loaded, try o.builder.intValue(.i8, 0), "");
        }

        const is_by_ref = operand_is_ptr or isByRef(optional_ty, mod);
        return self.optCmpNull(cond, optional_llvm_ty, operand, is_by_ref);
    }

    fn airIsErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        cond: Builder.IntegerCondition,
        operand_is_ptr: bool,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(mod) else operand_ty;
        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const error_type = try o.errorIntType();
        const zero = try o.builder.intValue(error_type, 0);

        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            const val: Builder.Constant = switch (cond) {
                .eq => .true, // 0 == 0
                .ne => .false, // 0 != 0
                else => unreachable,
            };
            return val.toValue();
        }

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(.normal, try o.lowerType(err_union_ty), operand, .default, "")
            else
                operand;
            return self.wip.icmp(cond, loaded, zero, "");
        }

        const err_field_index = try errUnionErrorOffset(payload_ty, mod);

        const loaded = if (operand_is_ptr or isByRef(err_union_ty, mod)) loaded: {
            const err_union_llvm_ty = try o.lowerType(err_union_ty);
            const err_field_ptr =
                try self.wip.gepStruct(err_union_llvm_ty, operand, err_field_index, "");
            break :loaded try self.wip.load(.normal, error_type, err_field_ptr, .default, "");
        } else try self.wip.extractValue(operand, &.{err_field_index}, "");
        return self.wip.icmp(cond, loaded, zero, "");
    }

    fn airOptionalPayloadPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand).childType(mod);
        const payload_ty = optional_ty.optionalChild(mod);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            // We have a pointer to a zero-bit value and we need to return
            // a pointer to a zero-bit value.
            return operand;
        }
        if (optional_ty.optionalReprIsPayload(mod)) {
            // The payload and the optional are the same value.
            return operand;
        }
        return self.wip.gepStruct(try o.lowerType(optional_ty), operand, 0, "");
    }

    fn airOptionalPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        comptime assert(optional_layout_version == 3);

        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand).childType(mod);
        const payload_ty = optional_ty.optionalChild(mod);
        const non_null_bit = try o.builder.intValue(.i8, 1);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            // We have a pointer to a i8. We need to set it to 1 and then return the same pointer.
            _ = try self.wip.store(.normal, non_null_bit, operand, .default);
            return operand;
        }
        if (optional_ty.optionalReprIsPayload(mod)) {
            // The payload and the optional are the same value.
            // Setting to non-null will be done when the payload is set.
            return operand;
        }

        // First set the non-null bit.
        const optional_llvm_ty = try o.lowerType(optional_ty);
        const non_null_ptr = try self.wip.gepStruct(optional_llvm_ty, operand, 1, "");
        // TODO set alignment on this store
        _ = try self.wip.store(.normal, non_null_bit, non_null_ptr, .default);

        // Then return the payload pointer (only if it's used).
        if (self.liveness.isUnused(inst)) return .none;

        return self.wip.gepStruct(optional_llvm_ty, operand, 0, "");
    }

    fn airOptionalPayload(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return .none;

        if (optional_ty.optionalReprIsPayload(mod)) {
            // Payload value is the same as the optional value.
            return operand;
        }

        const opt_llvm_ty = try o.lowerType(optional_ty);
        const can_elide_load = if (isByRef(payload_ty, mod)) self.canElideLoad(body_tail) else false;
        return self.optPayloadHandle(opt_llvm_ty, operand, optional_ty, can_elide_load);
    }

    fn airErrUnionPayload(
        self: *FuncGen,
        body_tail: []const Air.Inst.Index,
        operand_is_ptr: bool,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(mod) else operand_ty;
        const result_ty = self.typeOfIndex(inst);
        const payload_ty = if (operand_is_ptr) result_ty.childType(mod) else result_ty;

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            return if (operand_is_ptr) operand else .none;
        }
        const offset = try errUnionPayloadOffset(payload_ty, mod);
        const err_union_llvm_ty = try o.lowerType(err_union_ty);
        if (operand_is_ptr) {
            return self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
        } else if (isByRef(err_union_ty, mod)) {
            const payload_alignment = payload_ty.abiAlignment(mod).toLlvm();
            const payload_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
            if (isByRef(payload_ty, mod)) {
                if (self.canElideLoad(body_tail)) return payload_ptr;
                return self.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            const payload_llvm_ty = err_union_llvm_ty.structFields(&o.builder)[offset];
            return self.wip.load(.normal, payload_llvm_ty, payload_ptr, payload_alignment, "");
        }
        return self.wip.extractValue(operand, &.{offset}, "");
    }

    fn airErrUnionErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const error_type = try o.errorIntType();
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(mod) else operand_ty;
        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            if (operand_is_ptr) {
                return operand;
            } else {
                return o.builder.intValue(error_type, 0);
            }
        }

        const payload_ty = err_union_ty.errorUnionPayload(mod);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            if (!operand_is_ptr) return operand;
            return self.wip.load(.normal, error_type, operand, .default, "");
        }

        const offset = try errUnionErrorOffset(payload_ty, mod);

        if (operand_is_ptr or isByRef(err_union_ty, mod)) {
            const err_union_llvm_ty = try o.lowerType(err_union_ty);
            const err_field_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
            return self.wip.load(.normal, error_type, err_field_ptr, .default, "");
        }

        return self.wip.extractValue(operand, &.{offset}, "");
    }

    fn airErrUnionPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const err_union_ty = self.typeOf(ty_op.operand).childType(mod);

        const payload_ty = err_union_ty.errorUnionPayload(mod);
        const non_error_val = try o.builder.intValue(try o.errorIntType(), 0);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            _ = try self.wip.store(.normal, non_error_val, operand, .default);
            return operand;
        }
        const err_union_llvm_ty = try o.lowerType(err_union_ty);
        {
            const err_int_ty = try mod.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(mod).toLlvm();
            const error_offset = try errUnionErrorOffset(payload_ty, mod);
            // First set the non-error value.
            const non_null_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, error_offset, "");
            _ = try self.wip.store(.normal, non_error_val, non_null_ptr, error_alignment);
        }
        // Then return the payload pointer (only if it is used).
        if (self.liveness.isUnused(inst)) return .none;

        const payload_offset = try errUnionPayloadOffset(payload_ty, mod);
        return self.wip.gepStruct(err_union_llvm_ty, operand, payload_offset, "");
    }

    fn airErrReturnTrace(self: *FuncGen, _: Air.Inst.Index) !Builder.Value {
        assert(self.err_ret_trace != .none);
        return self.err_ret_trace;
    }

    fn airSetErrReturnTrace(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        self.err_ret_trace = try self.resolveInst(un_op);
        return .none;
    }

    fn airSaveErrReturnTraceIndex(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_ty = ty_pl.ty.toType();
        const field_index = ty_pl.payload;

        const mod = o.module;
        const struct_llvm_ty = try o.lowerType(struct_ty);
        const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
        assert(self.err_ret_trace != .none);
        const field_ptr =
            try self.wip.gepStruct(struct_llvm_ty, self.err_ret_trace, llvm_field_index, "");
        const field_alignment = struct_ty.structFieldAlign(field_index, mod);
        const field_ty = struct_ty.structFieldType(field_index, mod);
        const field_ptr_ty = try mod.ptrType(.{
            .child = field_ty.toIntern(),
            .flags = .{ .alignment = field_alignment },
        });
        return self.load(field_ptr, field_ptr_ty);
    }

    /// As an optimization, we want to avoid unnecessary copies of
    /// error union/optional types when returning from a function.
    /// Here, we scan forward in the current block, looking to see
    /// if the next instruction is a return (ignoring debug instructions).
    ///
    /// The first instruction of `body_tail` is a wrap instruction.
    fn isNextRet(
        self: *FuncGen,
        body_tail: []const Air.Inst.Index,
    ) bool {
        const air_tags = self.air.instructions.items(.tag);
        for (body_tail[1..]) |body_inst| {
            switch (air_tags[@intFromEnum(body_inst)]) {
                .ret => return true,
                .dbg_block_begin, .dbg_stmt => continue,
                else => return false,
            }
        }
        // The only way to get here is to hit the end of a loop instruction
        // (implicit repeat).
        return false;
    }

    fn airWrapOptional(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const payload_ty = self.typeOf(ty_op.operand);
        const non_null_bit = try o.builder.intValue(.i8, 1);
        comptime assert(optional_layout_version == 3);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return non_null_bit;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOfIndex(inst);
        if (optional_ty.optionalReprIsPayload(mod)) return operand;
        const llvm_optional_ty = try o.lowerType(optional_ty);
        if (isByRef(optional_ty, mod)) {
            const directReturn = self.isNextRet(body_tail);
            const optional_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = optional_ty.abiAlignment(mod).toLlvm();
                const optional_ptr = try self.buildAllocaWorkaround(optional_ty, alignment);
                break :brk optional_ptr;
            };

            const payload_ptr = try self.wip.gepStruct(llvm_optional_ty, optional_ptr, 0, "");
            const payload_ptr_ty = try mod.singleMutPtrType(payload_ty);
            try self.store(payload_ptr, payload_ptr_ty, operand, .none);
            const non_null_ptr = try self.wip.gepStruct(llvm_optional_ty, optional_ptr, 1, "");
            _ = try self.wip.store(.normal, non_null_bit, non_null_ptr, .default);
            return optional_ptr;
        }
        return self.wip.buildAggregate(llvm_optional_ty, &.{ operand, non_null_bit }, "");
    }

    fn airWrapErrUnionPayload(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_un_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);
        const payload_ty = self.typeOf(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            return operand;
        }
        const ok_err_code = try o.builder.intValue(try o.errorIntType(), 0);
        const err_un_llvm_ty = try o.lowerType(err_un_ty);

        const payload_offset = try errUnionPayloadOffset(payload_ty, mod);
        const error_offset = try errUnionErrorOffset(payload_ty, mod);
        if (isByRef(err_un_ty, mod)) {
            const directReturn = self.isNextRet(body_tail);
            const result_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = err_un_ty.abiAlignment(mod).toLlvm();
                const result_ptr = try self.buildAllocaWorkaround(err_un_ty, alignment);
                break :brk result_ptr;
            };

            const err_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, error_offset, "");
            const err_int_ty = try mod.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(mod).toLlvm();
            _ = try self.wip.store(.normal, ok_err_code, err_ptr, error_alignment);
            const payload_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, payload_offset, "");
            const payload_ptr_ty = try mod.singleMutPtrType(payload_ty);
            try self.store(payload_ptr, payload_ptr_ty, operand, .none);
            return result_ptr;
        }
        var fields: [2]Builder.Value = undefined;
        fields[payload_offset] = operand;
        fields[error_offset] = ok_err_code;
        return self.wip.buildAggregate(err_un_llvm_ty, &fields, "");
    }

    fn airWrapErrUnionErr(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_un_ty = self.typeOfIndex(inst);
        const payload_ty = err_un_ty.errorUnionPayload(mod);
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) return operand;
        const err_un_llvm_ty = try o.lowerType(err_un_ty);

        const payload_offset = try errUnionPayloadOffset(payload_ty, mod);
        const error_offset = try errUnionErrorOffset(payload_ty, mod);
        if (isByRef(err_un_ty, mod)) {
            const directReturn = self.isNextRet(body_tail);
            const result_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = err_un_ty.abiAlignment(mod).toLlvm();
                const result_ptr = try self.buildAllocaWorkaround(err_un_ty, alignment);
                break :brk result_ptr;
            };

            const err_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, error_offset, "");
            const err_int_ty = try mod.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(mod).toLlvm();
            _ = try self.wip.store(.normal, operand, err_ptr, error_alignment);
            const payload_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, payload_offset, "");
            const payload_ptr_ty = try mod.singleMutPtrType(payload_ty);
            // TODO store undef to payload_ptr
            _ = payload_ptr;
            _ = payload_ptr_ty;
            return result_ptr;
        }

        // TODO set payload bytes to undef
        const undef = try o.builder.undefValue(err_un_llvm_ty);
        return self.wip.insertValue(undef, operand, &.{error_offset}, "");
    }

    fn airWasmMemorySize(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const index = pl_op.payload;
        return self.wip.callIntrinsic(.normal, .none, .@"wasm.memory.size", &.{.i32}, &.{
            try o.builder.intValue(.i32, index),
        }, "");
    }

    fn airWasmMemoryGrow(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const index = pl_op.payload;
        return self.wip.callIntrinsic(.normal, .none, .@"wasm.memory.grow", &.{.i32}, &.{
            try o.builder.intValue(.i32, index), try self.resolveInst(pl_op.operand),
        }, "");
    }

    fn airVectorStoreElem(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const data = self.air.instructions.items(.data)[@intFromEnum(inst)].vector_store_elem;
        const extra = self.air.extraData(Air.Bin, data.payload).data;

        const vector_ptr = try self.resolveInst(data.vector_ptr);
        const vector_ptr_ty = self.typeOf(data.vector_ptr);
        const index = try self.resolveInst(extra.lhs);
        const operand = try self.resolveInst(extra.rhs);

        const access_kind: Builder.MemoryAccessKind =
            if (vector_ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal;
        const elem_llvm_ty = try o.lowerType(vector_ptr_ty.childType(mod));
        const alignment = vector_ptr_ty.ptrAlignment(mod).toLlvm();
        const loaded = try self.wip.load(access_kind, elem_llvm_ty, vector_ptr, alignment, "");

        const new_vector = try self.wip.insertElement(loaded, operand, index, "");
        _ = try self.store(vector_ptr, vector_ptr_ty, new_vector, .none);
        return .none;
    }

    fn airMin(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.fmin, .normal, inst_ty, 2, .{ lhs, rhs });
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(mod)) .smin else .umin,
            &.{try o.lowerType(inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airMax(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.fmax, .normal, inst_ty, 2, .{ lhs, rhs });
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(mod)) .smax else .umax,
            &.{try o.lowerType(inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airSlice(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        return self.wip.buildAggregate(try o.lowerType(inst_ty), &.{ ptr, len }, "");
    }

    fn airAdd(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.add, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(mod)) .@"add nsw" else .@"add nuw", lhs, rhs, "");
    }

    fn airSafeArithmetic(
        fg: *FuncGen,
        inst: Air.Inst.Index,
        signed_intrinsic: Builder.Intrinsic,
        unsigned_intrinsic: Builder.Intrinsic,
    ) !Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;

        const bin_op = fg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try fg.resolveInst(bin_op.lhs);
        const rhs = try fg.resolveInst(bin_op.rhs);
        const inst_ty = fg.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        const intrinsic = if (scalar_ty.isSignedInt(mod)) signed_intrinsic else unsigned_intrinsic;
        const llvm_inst_ty = try o.lowerType(inst_ty);
        const results =
            try fg.wip.callIntrinsic(.normal, .none, intrinsic, &.{llvm_inst_ty}, &.{ lhs, rhs }, "");

        const overflow_bits = try fg.wip.extractValue(results, &.{1}, "");
        const overflow_bits_ty = overflow_bits.typeOfWip(&fg.wip);
        const overflow_bit = if (overflow_bits_ty.isVector(&o.builder))
            try fg.wip.callIntrinsic(
                .normal,
                .none,
                .@"vector.reduce.or",
                &.{overflow_bits_ty},
                &.{overflow_bits},
                "",
            )
        else
            overflow_bits;

        const fail_block = try fg.wip.block(1, "OverflowFail");
        const ok_block = try fg.wip.block(1, "OverflowOk");
        _ = try fg.wip.brCond(overflow_bit, fail_block, ok_block);

        fg.wip.cursor = .{ .block = fail_block };
        try fg.buildSimplePanic(.integer_overflow);

        fg.wip.cursor = .{ .block = ok_block };
        return fg.wip.extractValue(results, &.{0}, "");
    }

    fn airAddWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.add, lhs, rhs, "");
    }

    fn airAddSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float add", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(mod)) .@"sadd.sat" else .@"uadd.sat",
            &.{try o.lowerType(inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airSub(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.sub, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(mod)) .@"sub nsw" else .@"sub nuw", lhs, rhs, "");
    }

    fn airSubWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.sub, lhs, rhs, "");
    }

    fn airSubSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float sub", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(mod)) .@"ssub.sat" else .@"usub.sat",
            &.{try o.lowerType(inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airMul(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.mul, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(mod)) .@"mul nsw" else .@"mul nuw", lhs, rhs, "");
    }

    fn airMulWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.mul, lhs, rhs, "");
    }

    fn airMulSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float mul", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(mod)) .@"smul.fix.sat" else .@"umul.fix.sat",
            &.{try o.lowerType(inst_ty)},
            &.{ lhs, rhs, try o.builder.intValue(.i32, 0) },
            "",
        );
    }

    fn airDivFloat(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);

        return self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
    }

    fn airDivTrunc(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isRuntimeFloat()) {
            const result = try self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
            return self.buildFloatOp(.trunc, fast, inst_ty, 1, .{result});
        }
        return self.wip.bin(if (scalar_ty.isSignedInt(mod)) .sdiv else .udiv, lhs, rhs, "");
    }

    fn airDivFloor(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isRuntimeFloat()) {
            const result = try self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
            return self.buildFloatOp(.floor, fast, inst_ty, 1, .{result});
        }
        if (scalar_ty.isSignedInt(mod)) {
            const inst_llvm_ty = try o.lowerType(inst_ty);
            const bit_size_minus_one = try o.builder.splatValue(inst_llvm_ty, try o.builder.intConst(
                inst_llvm_ty.scalarType(&o.builder),
                inst_llvm_ty.scalarBits(&o.builder) - 1,
            ));

            const div = try self.wip.bin(.sdiv, lhs, rhs, "");
            const rem = try self.wip.bin(.srem, lhs, rhs, "");
            const div_sign = try self.wip.bin(.xor, lhs, rhs, "");
            const div_sign_mask = try self.wip.bin(.ashr, div_sign, bit_size_minus_one, "");
            const zero = try o.builder.zeroInitValue(inst_llvm_ty);
            const rem_nonzero = try self.wip.icmp(.ne, rem, zero, "");
            const correction = try self.wip.select(.normal, rem_nonzero, div_sign_mask, zero, "");
            return self.wip.bin(.@"add nsw", div, correction, "");
        }
        return self.wip.bin(.udiv, lhs, rhs, "");
    }

    fn airDivExact(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isRuntimeFloat()) return self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(
            if (scalar_ty.isSignedInt(mod)) .@"sdiv exact" else .@"udiv exact",
            lhs,
            rhs,
            "",
        );
    }

    fn airRem(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isRuntimeFloat())
            return self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(mod))
            .srem
        else
            .urem, lhs, rhs, "");
    }

    fn airMod(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const inst_llvm_ty = try o.lowerType(inst_ty);
        const scalar_ty = inst_ty.scalarType(mod);

        if (scalar_ty.isRuntimeFloat()) {
            const a = try self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ lhs, rhs });
            const b = try self.buildFloatOp(.add, fast, inst_ty, 2, .{ a, rhs });
            const c = try self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ b, rhs });
            const zero = try o.builder.zeroInitValue(inst_llvm_ty);
            const ltz = try self.buildFloatCmp(fast, .lt, inst_ty, .{ lhs, zero });
            return self.wip.select(fast, ltz, c, a, "");
        }
        if (scalar_ty.isSignedInt(mod)) {
            const bit_size_minus_one = try o.builder.splatValue(inst_llvm_ty, try o.builder.intConst(
                inst_llvm_ty.scalarType(&o.builder),
                inst_llvm_ty.scalarBits(&o.builder) - 1,
            ));

            const rem = try self.wip.bin(.srem, lhs, rhs, "");
            const div_sign = try self.wip.bin(.xor, lhs, rhs, "");
            const div_sign_mask = try self.wip.bin(.ashr, div_sign, bit_size_minus_one, "");
            const rhs_masked = try self.wip.bin(.@"and", rhs, div_sign_mask, "");
            const zero = try o.builder.zeroInitValue(inst_llvm_ty);
            const rem_nonzero = try self.wip.icmp(.ne, rem, zero, "");
            const correction = try self.wip.select(.normal, rem_nonzero, rhs_masked, zero, "");
            return self.wip.bin(.@"add nsw", rem, correction, "");
        }
        return self.wip.bin(.urem, lhs, rhs, "");
    }

    fn airPtrAdd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(ptr_ty.childType(mod));
        switch (ptr_ty.ptrSize(mod)) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            .One => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{
                try o.builder.intValue(try o.lowerType(Type.usize), 0), offset,
            }, ""),
            .C, .Many => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{offset}, ""),
            .Slice => {
                const base = try self.wip.extractValue(ptr, &.{0}, "");
                return self.wip.gep(.inbounds, llvm_elem_ty, base, &.{offset}, "");
            },
        }
    }

    fn airPtrSub(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const negative_offset = try self.wip.neg(offset, "");
        const ptr_ty = self.typeOf(bin_op.lhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(ptr_ty.childType(mod));
        switch (ptr_ty.ptrSize(mod)) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            .One => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{
                try o.builder.intValue(try o.lowerType(Type.usize), 0), negative_offset,
            }, ""),
            .C, .Many => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{negative_offset}, ""),
            .Slice => {
                const base = try self.wip.extractValue(ptr, &.{0}, "");
                return self.wip.gep(.inbounds, llvm_elem_ty, base, &.{negative_offset}, "");
            },
        }
    }

    fn airOverflow(
        self: *FuncGen,
        inst: Air.Inst.Index,
        signed_intrinsic: Builder.Intrinsic,
        unsigned_intrinsic: Builder.Intrinsic,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.typeOf(extra.lhs);
        const scalar_ty = lhs_ty.scalarType(mod);
        const inst_ty = self.typeOfIndex(inst);

        const intrinsic = if (scalar_ty.isSignedInt(mod)) signed_intrinsic else unsigned_intrinsic;
        const llvm_inst_ty = try o.lowerType(inst_ty);
        const llvm_lhs_ty = try o.lowerType(lhs_ty);
        const results =
            try self.wip.callIntrinsic(.normal, .none, intrinsic, &.{llvm_lhs_ty}, &.{ lhs, rhs }, "");

        const result_val = try self.wip.extractValue(results, &.{0}, "");
        const overflow_bit = try self.wip.extractValue(results, &.{1}, "");

        const result_index = o.llvmFieldIndex(inst_ty, 0).?;
        const overflow_index = o.llvmFieldIndex(inst_ty, 1).?;

        if (isByRef(inst_ty, mod)) {
            const result_alignment = inst_ty.abiAlignment(mod).toLlvm();
            const alloca_inst = try self.buildAllocaWorkaround(inst_ty, result_alignment);
            {
                const field_ptr = try self.wip.gepStruct(llvm_inst_ty, alloca_inst, result_index, "");
                _ = try self.wip.store(.normal, result_val, field_ptr, result_alignment);
            }
            {
                const overflow_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(llvm_inst_ty, alloca_inst, overflow_index, "");
                _ = try self.wip.store(.normal, overflow_bit, field_ptr, overflow_alignment);
            }

            return alloca_inst;
        }

        var fields: [2]Builder.Value = undefined;
        fields[result_index] = result_val;
        fields[overflow_index] = overflow_bit;
        return self.wip.buildAggregate(llvm_inst_ty, &fields, "");
    }

    fn buildElementwiseCall(
        self: *FuncGen,
        llvm_fn: Builder.Function.Index,
        args_vectors: []const Builder.Value,
        result_vector: Builder.Value,
        vector_len: usize,
    ) !Builder.Value {
        const o = self.dg.object;
        assert(args_vectors.len <= 3);

        var i: usize = 0;
        var result = result_vector;
        while (i < vector_len) : (i += 1) {
            const index_i32 = try o.builder.intValue(.i32, i);

            var args: [3]Builder.Value = undefined;
            for (args[0..args_vectors.len], args_vectors) |*arg_elem, arg_vector| {
                arg_elem.* = try self.wip.extractElement(arg_vector, index_i32, "");
            }
            const result_elem = try self.wip.call(
                .normal,
                .ccc,
                .none,
                llvm_fn.typeOf(&o.builder),
                llvm_fn.toValue(&o.builder),
                args[0..args_vectors.len],
                "",
            );
            result = try self.wip.insertElement(result, result_elem, index_i32, "");
        }
        return result;
    }

    fn getLibcFunction(
        self: *FuncGen,
        fn_name: Builder.String,
        param_types: []const Builder.Type,
        return_type: Builder.Type,
    ) Allocator.Error!Builder.Function.Index {
        const o = self.dg.object;
        if (o.builder.getGlobal(fn_name)) |global| return switch (global.ptrConst(&o.builder).kind) {
            .alias => |alias| alias.getAliasee(&o.builder).ptrConst(&o.builder).kind.function,
            .function => |function| function,
            .variable, .replaced => unreachable,
        };
        return o.builder.addFunction(
            try o.builder.fnType(return_type, param_types, .normal),
            fn_name,
            toLlvmAddressSpace(.generic, o.module.getTarget()),
        );
    }

    /// Creates a floating point comparison by lowering to the appropriate
    /// hardware instruction or softfloat routine for the target
    fn buildFloatCmp(
        self: *FuncGen,
        fast: Builder.FastMathKind,
        pred: math.CompareOperator,
        ty: Type,
        params: [2]Builder.Value,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const target = o.module.getTarget();
        const scalar_ty = ty.scalarType(mod);
        const scalar_llvm_ty = try o.lowerType(scalar_ty);

        if (intrinsicsAllowed(scalar_ty, target)) {
            const cond: Builder.FloatCondition = switch (pred) {
                .eq => .oeq,
                .neq => .une,
                .lt => .olt,
                .lte => .ole,
                .gt => .ogt,
                .gte => .oge,
            };
            return self.wip.fcmp(fast, cond, params[0], params[1], "");
        }

        const float_bits = scalar_ty.floatBits(target);
        const compiler_rt_float_abbrev = compilerRtFloatAbbrev(float_bits);
        const fn_base_name = switch (pred) {
            .neq => "ne",
            .eq => "eq",
            .lt => "lt",
            .lte => "le",
            .gt => "gt",
            .gte => "ge",
        };
        const fn_name = try o.builder.fmt("__{s}{s}f2", .{ fn_base_name, compiler_rt_float_abbrev });

        const libc_fn = try self.getLibcFunction(fn_name, &.{ scalar_llvm_ty, scalar_llvm_ty }, .i32);

        const zero = try o.builder.intConst(.i32, 0);
        const int_cond: Builder.IntegerCondition = switch (pred) {
            .eq => .eq,
            .neq => .ne,
            .lt => .slt,
            .lte => .sle,
            .gt => .sgt,
            .gte => .sge,
        };

        if (ty.zigTypeTag(mod) == .Vector) {
            const vec_len = ty.vectorLen(mod);
            const vector_result_ty = try o.builder.vectorType(.normal, vec_len, .i32);

            const init = try o.builder.poisonValue(vector_result_ty);
            const result = try self.buildElementwiseCall(libc_fn, &params, init, vec_len);

            const zero_vector = try o.builder.splatValue(vector_result_ty, zero);
            return self.wip.icmp(int_cond, result, zero_vector, "");
        }

        const result = try self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &params,
            "",
        );
        return self.wip.icmp(int_cond, result, zero.toValue(), "");
    }

    const FloatOp = enum {
        add,
        ceil,
        cos,
        div,
        exp,
        exp2,
        fabs,
        floor,
        fma,
        fmax,
        fmin,
        fmod,
        log,
        log10,
        log2,
        mul,
        neg,
        round,
        sin,
        sqrt,
        sub,
        tan,
        trunc,
    };

    const FloatOpStrat = union(enum) {
        intrinsic: []const u8,
        libc: Builder.String,
    };

    /// Creates a floating point operation (add, sub, fma, sqrt, exp, etc.)
    /// by lowering to the appropriate hardware instruction or softfloat
    /// routine for the target
    fn buildFloatOp(
        self: *FuncGen,
        comptime op: FloatOp,
        fast: Builder.FastMathKind,
        ty: Type,
        comptime params_len: usize,
        params: [params_len]Builder.Value,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const target = mod.getTarget();
        const scalar_ty = ty.scalarType(mod);
        const llvm_ty = try o.lowerType(ty);

        if (op != .tan and intrinsicsAllowed(scalar_ty, target)) switch (op) {
            // Some operations are dedicated LLVM instructions, not available as intrinsics
            .neg => return self.wip.un(.fneg, params[0], ""),
            .add, .sub, .mul, .div, .fmod => return self.wip.bin(switch (fast) {
                .normal => switch (op) {
                    .add => .fadd,
                    .sub => .fsub,
                    .mul => .fmul,
                    .div => .fdiv,
                    .fmod => .frem,
                    else => unreachable,
                },
                .fast => switch (op) {
                    .add => .@"fadd fast",
                    .sub => .@"fsub fast",
                    .mul => .@"fmul fast",
                    .div => .@"fdiv fast",
                    .fmod => .@"frem fast",
                    else => unreachable,
                },
            }, params[0], params[1], ""),
            .fmax,
            .fmin,
            .ceil,
            .cos,
            .exp,
            .exp2,
            .fabs,
            .floor,
            .log,
            .log10,
            .log2,
            .round,
            .sin,
            .sqrt,
            .trunc,
            .fma,
            => return self.wip.callIntrinsic(fast, .none, switch (op) {
                .fmax => .maxnum,
                .fmin => .minnum,
                .ceil => .ceil,
                .cos => .cos,
                .exp => .exp,
                .exp2 => .exp2,
                .fabs => .fabs,
                .floor => .floor,
                .log => .log,
                .log10 => .log10,
                .log2 => .log2,
                .round => .round,
                .sin => .sin,
                .sqrt => .sqrt,
                .trunc => .trunc,
                .fma => .fma,
                else => unreachable,
            }, &.{llvm_ty}, &params, ""),
            .tan => unreachable,
        };

        const float_bits = scalar_ty.floatBits(target);
        const fn_name = switch (op) {
            .neg => {
                // In this case we can generate a softfloat negation by XORing the
                // bits with a constant.
                const int_ty = try o.builder.intType(@intCast(float_bits));
                const cast_ty = try llvm_ty.changeScalar(int_ty, &o.builder);
                const sign_mask = try o.builder.splatValue(
                    cast_ty,
                    try o.builder.intConst(int_ty, @as(u128, 1) << @intCast(float_bits - 1)),
                );
                const bitcasted_operand = try self.wip.cast(.bitcast, params[0], cast_ty, "");
                const result = try self.wip.bin(.xor, bitcasted_operand, sign_mask, "");
                return self.wip.cast(.bitcast, result, llvm_ty, "");
            },
            .add, .sub, .div, .mul => try o.builder.fmt("__{s}{s}f3", .{
                @tagName(op), compilerRtFloatAbbrev(float_bits),
            }),
            .ceil,
            .cos,
            .exp,
            .exp2,
            .fabs,
            .floor,
            .fma,
            .fmax,
            .fmin,
            .fmod,
            .log,
            .log10,
            .log2,
            .round,
            .sin,
            .sqrt,
            .tan,
            .trunc,
            => try o.builder.fmt("{s}{s}{s}", .{
                libcFloatPrefix(float_bits), @tagName(op), libcFloatSuffix(float_bits),
            }),
        };

        const scalar_llvm_ty = llvm_ty.scalarType(&o.builder);
        const libc_fn = try self.getLibcFunction(
            fn_name,
            ([1]Builder.Type{scalar_llvm_ty} ** 3)[0..params.len],
            scalar_llvm_ty,
        );
        if (ty.zigTypeTag(mod) == .Vector) {
            const result = try o.builder.poisonValue(llvm_ty);
            return self.buildElementwiseCall(libc_fn, &params, result, ty.vectorLen(mod));
        }

        return self.wip.call(
            fast.toCallKind(),
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &params,
            "",
        );
    }

    fn airMulAdd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

        const mulend1 = try self.resolveInst(extra.lhs);
        const mulend2 = try self.resolveInst(extra.rhs);
        const addend = try self.resolveInst(pl_op.operand);

        const ty = self.typeOfIndex(inst);
        return self.buildFloatOp(.fma, .normal, ty, 3, .{ mulend1, mulend2, addend });
    }

    fn airShlWithOverflow(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.typeOf(extra.lhs);
        const lhs_scalar_ty = lhs_ty.scalarType(mod);

        const dest_ty = self.typeOfIndex(inst);
        const llvm_dest_ty = try o.lowerType(dest_ty);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(lhs_ty), "");

        const result = try self.wip.bin(.shl, lhs, casted_rhs, "");
        const reconstructed = try self.wip.bin(if (lhs_scalar_ty.isSignedInt(mod))
            .ashr
        else
            .lshr, result, casted_rhs, "");

        const overflow_bit = try self.wip.icmp(.ne, lhs, reconstructed, "");

        const result_index = o.llvmFieldIndex(dest_ty, 0).?;
        const overflow_index = o.llvmFieldIndex(dest_ty, 1).?;

        if (isByRef(dest_ty, mod)) {
            const result_alignment = dest_ty.abiAlignment(mod).toLlvm();
            const alloca_inst = try self.buildAllocaWorkaround(dest_ty, result_alignment);
            {
                const field_ptr = try self.wip.gepStruct(llvm_dest_ty, alloca_inst, result_index, "");
                _ = try self.wip.store(.normal, result, field_ptr, result_alignment);
            }
            {
                const field_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(llvm_dest_ty, alloca_inst, overflow_index, "");
                _ = try self.wip.store(.normal, overflow_bit, field_ptr, field_alignment);
            }
            return alloca_inst;
        }

        var fields: [2]Builder.Value = undefined;
        fields[result_index] = result;
        fields[overflow_index] = overflow_bit;
        return self.wip.buildAggregate(llvm_dest_ty, &fields, "");
    }

    fn airAnd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.@"and", lhs, rhs, "");
    }

    fn airOr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.@"or", lhs, rhs, "");
    }

    fn airXor(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.xor, lhs, rhs, "");
    }

    fn airShlExact(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        const lhs_scalar_ty = lhs_ty.scalarType(mod);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(lhs_ty), "");
        return self.wip.bin(if (lhs_scalar_ty.isSignedInt(mod))
            .@"shl nsw"
        else
            .@"shl nuw", lhs, casted_rhs, "");
    }

    fn airShl(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_type = self.typeOf(bin_op.lhs);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(lhs_type), "");
        return self.wip.bin(.shl, lhs, casted_rhs, "");
    }

    fn airShlSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        const lhs_scalar_ty = lhs_ty.scalarType(mod);
        const lhs_bits = lhs_scalar_ty.bitSize(mod);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(lhs_ty), "");

        const llvm_lhs_ty = try o.lowerType(lhs_ty);
        const llvm_lhs_scalar_ty = llvm_lhs_ty.scalarType(&o.builder);
        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            if (lhs_scalar_ty.isSignedInt(mod)) .@"sshl.sat" else .@"ushl.sat",
            &.{llvm_lhs_ty},
            &.{ lhs, casted_rhs },
            "",
        );

        // LLVM langref says "If b is (statically or dynamically) equal to or
        // larger than the integer bit width of the arguments, the result is a
        // poison value."
        // However Zig semantics says that saturating shift left can never produce
        // undefined; instead it saturates.
        const bits = try o.builder.splatValue(
            llvm_lhs_ty,
            try o.builder.intConst(llvm_lhs_scalar_ty, lhs_bits),
        );
        const lhs_max = try o.builder.splatValue(
            llvm_lhs_ty,
            try o.builder.intConst(llvm_lhs_scalar_ty, -1),
        );
        const in_range = try self.wip.icmp(.ult, casted_rhs, bits, "");
        return self.wip.select(.normal, in_range, result, lhs_max, "");
    }

    fn airShr(self: *FuncGen, inst: Air.Inst.Index, is_exact: bool) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        const lhs_scalar_ty = lhs_ty.scalarType(mod);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(lhs_ty), "");
        const is_signed_int = lhs_scalar_ty.isSignedInt(mod);

        return self.wip.bin(if (is_exact)
            if (is_signed_int) .@"ashr exact" else .@"lshr exact"
        else if (is_signed_int) .ashr else .lshr, lhs, casted_rhs, "");
    }

    fn airAbs(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const scalar_ty = operand_ty.scalarType(mod);

        switch (scalar_ty.zigTypeTag(mod)) {
            .Int => return self.wip.callIntrinsic(
                .normal,
                .none,
                .abs,
                &.{try o.lowerType(operand_ty)},
                &.{ operand, try o.builder.intValue(.i1, 0) },
                "",
            ),
            .Float => return self.buildFloatOp(.fabs, .normal, operand_ty, 1, .{operand}),
            else => unreachable,
        }
    }

    fn airIntCast(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const dest_ty = self.typeOfIndex(inst);
        const dest_llvm_ty = try o.lowerType(dest_ty);
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_info = operand_ty.intInfo(mod);

        return self.wip.conv(switch (operand_info.signedness) {
            .signed => .signed,
            .unsigned => .unsigned,
        }, operand, dest_llvm_ty, "");
    }

    fn airTrunc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const dest_llvm_ty = try o.lowerType(self.typeOfIndex(inst));
        return self.wip.cast(.trunc, operand, dest_llvm_ty, "");
    }

    fn airFptrunc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const target = mod.getTarget();
        const dest_bits = dest_ty.floatBits(target);
        const src_bits = operand_ty.floatBits(target);

        if (intrinsicsAllowed(dest_ty, target) and intrinsicsAllowed(operand_ty, target)) {
            return self.wip.cast(.fptrunc, operand, try o.lowerType(dest_ty), "");
        } else {
            const operand_llvm_ty = try o.lowerType(operand_ty);
            const dest_llvm_ty = try o.lowerType(dest_ty);

            const fn_name = try o.builder.fmt("__trunc{s}f{s}f2", .{
                compilerRtFloatAbbrev(src_bits), compilerRtFloatAbbrev(dest_bits),
            });

            const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, dest_llvm_ty);
            return self.wip.call(
                .normal,
                .ccc,
                .none,
                libc_fn.typeOf(&o.builder),
                libc_fn.toValue(&o.builder),
                &.{operand},
                "",
            );
        }
    }

    fn airFpext(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const target = mod.getTarget();
        const dest_bits = dest_ty.floatBits(target);
        const src_bits = operand_ty.floatBits(target);

        if (intrinsicsAllowed(dest_ty, target) and intrinsicsAllowed(operand_ty, target)) {
            return self.wip.cast(.fpext, operand, try o.lowerType(dest_ty), "");
        } else {
            const operand_llvm_ty = try o.lowerType(operand_ty);
            const dest_llvm_ty = try o.lowerType(dest_ty);

            const fn_name = try o.builder.fmt("__extend{s}f{s}f2", .{
                compilerRtFloatAbbrev(src_bits), compilerRtFloatAbbrev(dest_bits),
            });

            const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, dest_llvm_ty);
            return self.wip.call(
                .normal,
                .ccc,
                .none,
                libc_fn.typeOf(&o.builder),
                libc_fn.toValue(&o.builder),
                &.{operand},
                "",
            );
        }
    }

    fn airIntFromPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const ptr_ty = self.typeOf(un_op);
        const operand_ptr = try self.sliceOrArrayPtr(operand, ptr_ty);
        const dest_llvm_ty = try o.lowerType(self.typeOfIndex(inst));
        return self.wip.cast(.ptrtoint, operand_ptr, dest_llvm_ty, "");
    }

    fn airBitCast(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const inst_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);
        return self.bitCast(operand, operand_ty, inst_ty);
    }

    fn bitCast(self: *FuncGen, operand: Builder.Value, operand_ty: Type, inst_ty: Type) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const operand_is_ref = isByRef(operand_ty, mod);
        const result_is_ref = isByRef(inst_ty, mod);
        const llvm_dest_ty = try o.lowerType(inst_ty);

        if (operand_is_ref and result_is_ref) {
            // They are both pointers, so just return the same opaque pointer :)
            return operand;
        }

        if (llvm_dest_ty.isInteger(&o.builder) and
            operand.typeOfWip(&self.wip).isInteger(&o.builder))
        {
            return self.wip.conv(.unsigned, operand, llvm_dest_ty, "");
        }

        if (operand_ty.zigTypeTag(mod) == .Int and inst_ty.isPtrAtRuntime(mod)) {
            return self.wip.cast(.inttoptr, operand, llvm_dest_ty, "");
        }

        if (operand_ty.zigTypeTag(mod) == .Vector and inst_ty.zigTypeTag(mod) == .Array) {
            const elem_ty = operand_ty.childType(mod);
            if (!result_is_ref) {
                return self.dg.todo("implement bitcast vector to non-ref array", .{});
            }
            const array_ptr = try self.buildAllocaWorkaround(inst_ty, .default);
            const bitcast_ok = elem_ty.bitSize(mod) == elem_ty.abiSize(mod) * 8;
            if (bitcast_ok) {
                const alignment = inst_ty.abiAlignment(mod).toLlvm();
                _ = try self.wip.store(.normal, operand, array_ptr, alignment);
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const llvm_usize = try o.lowerType(Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const vector_len = operand_ty.arrayLen(mod);
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_dest_ty, array_ptr, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const elem =
                        try self.wip.extractElement(operand, try o.builder.intValue(.i32, i), "");
                    _ = try self.wip.store(.normal, elem, elem_ptr, .default);
                }
            }
            return array_ptr;
        } else if (operand_ty.zigTypeTag(mod) == .Array and inst_ty.zigTypeTag(mod) == .Vector) {
            const elem_ty = operand_ty.childType(mod);
            const llvm_vector_ty = try o.lowerType(inst_ty);
            if (!operand_is_ref) return self.dg.todo("implement bitcast non-ref array to vector", .{});

            const bitcast_ok = elem_ty.bitSize(mod) == elem_ty.abiSize(mod) * 8;
            if (bitcast_ok) {
                // The array is aligned to the element's alignment, while the vector might have a completely
                // different alignment. This means we need to enforce the alignment of this load.
                const alignment = elem_ty.abiAlignment(mod).toLlvm();
                return self.wip.load(.normal, llvm_vector_ty, operand, alignment, "");
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const array_llvm_ty = try o.lowerType(operand_ty);
                const elem_llvm_ty = try o.lowerType(elem_ty);
                const llvm_usize = try o.lowerType(Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const vector_len = operand_ty.arrayLen(mod);
                var vector = try o.builder.poisonValue(llvm_vector_ty);
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const elem_ptr = try self.wip.gep(.inbounds, array_llvm_ty, operand, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const elem = try self.wip.load(.normal, elem_llvm_ty, elem_ptr, .default, "");
                    vector =
                        try self.wip.insertElement(vector, elem, try o.builder.intValue(.i32, i), "");
                }
                return vector;
            }
        }

        if (operand_is_ref) {
            const alignment = operand_ty.abiAlignment(mod).toLlvm();
            return self.wip.load(.normal, llvm_dest_ty, operand, alignment, "");
        }

        if (result_is_ref) {
            const alignment = operand_ty.abiAlignment(mod).max(inst_ty.abiAlignment(mod)).toLlvm();
            const result_ptr = try self.buildAllocaWorkaround(inst_ty, alignment);
            _ = try self.wip.store(.normal, operand, result_ptr, alignment);
            return result_ptr;
        }

        if (llvm_dest_ty.isStruct(&o.builder) or
            ((operand_ty.zigTypeTag(mod) == .Vector or inst_ty.zigTypeTag(mod) == .Vector) and operand_ty.bitSize(mod) != inst_ty.bitSize(mod)))
        {
            // Both our operand and our result are values, not pointers,
            // but LLVM won't let us bitcast struct values or vectors with padding bits.
            // Therefore, we store operand to alloca, then load for result.
            const alignment = operand_ty.abiAlignment(mod).max(inst_ty.abiAlignment(mod)).toLlvm();
            const result_ptr = try self.buildAllocaWorkaround(inst_ty, alignment);
            _ = try self.wip.store(.normal, operand, result_ptr, alignment);
            return self.wip.load(.normal, llvm_dest_ty, result_ptr, alignment, "");
        }

        return self.wip.cast(.bitcast, operand, llvm_dest_ty, "");
    }

    fn airIntFromBool(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        return operand;
    }

    fn airArg(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const arg_val = self.args[self.arg_index];
        self.arg_index += 1;

        const inst_ty = self.typeOfIndex(inst);
        if (o.di_builder) |dib| {
            if (needDbgVarWorkaround(o)) return arg_val;

            const src_index = self.air.instructions.items(.data)[@intFromEnum(inst)].arg.src_index;
            const func_index = self.dg.decl.getOwnedFunctionIndex();
            const func = mod.funcInfo(func_index);
            const lbrace_line = mod.declPtr(func.owner_decl).src_line + func.lbrace_line + 1;
            const lbrace_col = func.lbrace_column + 1;
            const di_local_var = dib.createParameterVariable(
                self.di_scope.?,
                mod.getParamName(func_index, src_index).ptr, // TODO test 0 bit args
                self.di_file.?,
                lbrace_line,
                try o.lowerDebugType(inst_ty, .full),
                true, // always preserve
                0, // flags
                @intCast(self.arg_index), // includes +1 because 0 is return type
            );

            const debug_loc = llvm.getDebugLoc(lbrace_line, lbrace_col, self.di_scope.?, null);
            const insert_block = self.wip.cursor.block.toLlvm(&self.wip);
            const owner_mod = self.dg.ownerModule();
            if (isByRef(inst_ty, mod)) {
                _ = dib.insertDeclareAtEnd(arg_val.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
            } else if (owner_mod.optimize_mode == .Debug) {
                const alignment = inst_ty.abiAlignment(mod).toLlvm();
                const alloca = try self.buildAlloca(arg_val.typeOfWip(&self.wip), alignment);
                _ = try self.wip.store(.normal, arg_val, alloca, alignment);
                _ = dib.insertDeclareAtEnd(alloca.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
            } else {
                _ = dib.insertDbgValueIntrinsicAtEnd(arg_val.toLlvm(&self.wip), di_local_var, debug_loc, insert_block);
            }
        }

        return arg_val;
    }

    fn airAlloc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ptr_ty = self.typeOfIndex(inst);
        const pointee_type = ptr_ty.childType(mod);
        if (!pointee_type.isFnOrHasRuntimeBitsIgnoreComptime(mod))
            return (try o.lowerPtrToVoid(ptr_ty)).toValue();

        //const pointee_llvm_ty = try o.lowerType(pointee_type);
        const alignment = ptr_ty.ptrAlignment(mod).toLlvm();
        return self.buildAllocaWorkaround(pointee_type, alignment);
    }

    fn airRetPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ptr_ty = self.typeOfIndex(inst);
        const ret_ty = ptr_ty.childType(mod);
        if (!ret_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod))
            return (try o.lowerPtrToVoid(ptr_ty)).toValue();
        if (self.ret_ptr != .none) return self.ret_ptr;
        //const ret_llvm_ty = try o.lowerType(ret_ty);
        const alignment = ptr_ty.ptrAlignment(mod).toLlvm();
        return self.buildAllocaWorkaround(ret_ty, alignment);
    }

    /// Use this instead of builder.buildAlloca, because this function makes sure to
    /// put the alloca instruction at the top of the function!
    fn buildAlloca(
        self: *FuncGen,
        llvm_ty: Builder.Type,
        alignment: Builder.Alignment,
    ) Allocator.Error!Builder.Value {
        const target = self.dg.object.module.getTarget();
        return buildAllocaInner(&self.wip, self.di_scope != null, llvm_ty, alignment, target);
    }

    // Workaround for https://github.com/ziglang/zig/issues/16392
    fn buildAllocaWorkaround(
        self: *FuncGen,
        ty: Type,
        alignment: Builder.Alignment,
    ) Allocator.Error!Builder.Value {
        const o = self.dg.object;
        return self.buildAlloca(try o.builder.arrayType(ty.abiSize(o.module), .i8), alignment);
    }

    fn airStore(self: *FuncGen, inst: Air.Inst.Index, safety: bool) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType(mod);

        const val_is_undef = if (try self.air.value(bin_op.rhs, mod)) |val| val.isUndefDeep(mod) else false;
        if (val_is_undef) {
            const ptr_info = ptr_ty.ptrInfo(mod);
            const needs_bitmask = (ptr_info.packed_offset.host_size != 0);
            if (needs_bitmask) {
                // TODO: only some bits are to be undef, we cannot write with a simple memset.
                // meanwhile, ignore the write rather than stomping over valid bits.
                // https://github.com/ziglang/zig/issues/15337
                return .none;
            }

            // Even if safety is disabled, we still emit a memset to undefined since it conveys
            // extra information to LLVM. However, safety makes the difference between using
            // 0xaa or actual undefined for the fill byte.
            const len = try o.builder.intValue(try o.lowerType(Type.usize), operand_ty.abiSize(mod));
            _ = try self.wip.callMemSet(
                dest_ptr,
                ptr_ty.ptrAlignment(mod).toLlvm(),
                if (safety) try o.builder.intValue(.i8, 0xaa) else try o.builder.undefValue(.i8),
                len,
                if (ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal,
            );
            const owner_mod = self.dg.ownerModule();
            if (safety and owner_mod.valgrind) {
                try self.valgrindMarkUndef(dest_ptr, len);
            }
            return .none;
        }

        const src_operand = try self.resolveInst(bin_op.rhs);
        try self.store(dest_ptr, ptr_ty, src_operand, .none);
        return .none;
    }

    /// As an optimization, we want to avoid unnecessary copies of isByRef=true
    /// types. Here, we scan forward in the current block, looking to see if
    /// this load dies before any side effects occur. In such case, we can
    /// safely return the operand without making a copy.
    ///
    /// The first instruction of `body_tail` is the one whose copy we want to elide.
    fn canElideLoad(fg: *FuncGen, body_tail: []const Air.Inst.Index) bool {
        const o = fg.dg.object;
        const mod = o.module;
        const ip = &mod.intern_pool;
        for (body_tail[1..]) |body_inst| {
            switch (fg.liveness.categorizeOperand(fg.air, body_inst, body_tail[0], ip)) {
                .none => continue,
                .write, .noret, .complex => return false,
                .tomb => return true,
            }
        }
        // The only way to get here is to hit the end of a loop instruction
        // (implicit repeat).
        return false;
    }

    fn airLoad(fg: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        const inst = body_tail[0];
        const ty_op = fg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const ptr_ty = fg.typeOf(ty_op.operand);
        const ptr_info = ptr_ty.ptrInfo(mod);
        const ptr = try fg.resolveInst(ty_op.operand);

        elide: {
            if (!isByRef(Type.fromInterned(ptr_info.child), mod)) break :elide;
            if (!canElideLoad(fg, body_tail)) break :elide;
            return ptr;
        }
        return fg.load(ptr, ptr_ty);
    }

    fn airTrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        _ = try self.wip.callIntrinsic(.normal, .none, .trap, &.{}, &.{}, "");
        _ = try self.wip.@"unreachable"();
        return .none;
    }

    fn airBreakpoint(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        _ = try self.wip.callIntrinsic(.normal, .none, .debugtrap, &.{}, &.{}, "");
        return .none;
    }

    fn airRetAddr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        const o = self.dg.object;
        const llvm_usize = try o.lowerType(Type.usize);
        if (!target_util.supportsReturnAddress(o.module.getTarget())) {
            // https://github.com/ziglang/zig/issues/11946
            return o.builder.intValue(llvm_usize, 0);
        }
        const result = try self.wip.callIntrinsic(.normal, .none, .returnaddress, &.{}, &.{
            try o.builder.intValue(.i32, 0),
        }, "");
        return self.wip.cast(.ptrtoint, result, llvm_usize, "");
    }

    fn airFrameAddress(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        const o = self.dg.object;
        const result = try self.wip.callIntrinsic(.normal, .none, .frameaddress, &.{.ptr}, &.{
            try o.builder.intValue(.i32, 0),
        }, "");
        return self.wip.cast(.ptrtoint, result, try o.lowerType(Type.usize), "");
    }

    fn airFence(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const atomic_order = self.air.instructions.items(.data)[@intFromEnum(inst)].fence;
        const ordering = toLlvmAtomicOrdering(atomic_order);
        _ = try self.wip.fence(self.sync_scope, ordering);
        return .none;
    }

    fn airCmpxchg(
        self: *FuncGen,
        inst: Air.Inst.Index,
        kind: Builder.Function.Instruction.CmpXchg.Kind,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
        const ptr = try self.resolveInst(extra.ptr);
        const ptr_ty = self.typeOf(extra.ptr);
        var expected_value = try self.resolveInst(extra.expected_value);
        var new_value = try self.resolveInst(extra.new_value);
        const operand_ty = ptr_ty.childType(mod);
        const llvm_operand_ty = try o.lowerType(operand_ty);
        const llvm_abi_ty = try o.getAtomicAbiType(operand_ty, false);
        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating
            const signedness: Builder.Function.Instruction.Cast.Signedness =
                if (operand_ty.isSignedInt(mod)) .signed else .unsigned;
            expected_value = try self.wip.conv(signedness, expected_value, llvm_abi_ty, "");
            new_value = try self.wip.conv(signedness, new_value, llvm_abi_ty, "");
        }

        const result = try self.wip.cmpxchg(
            kind,
            if (ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal,
            ptr,
            expected_value,
            new_value,
            self.sync_scope,
            toLlvmAtomicOrdering(extra.successOrder()),
            toLlvmAtomicOrdering(extra.failureOrder()),
            ptr_ty.ptrAlignment(mod).toLlvm(),
            "",
        );

        const optional_ty = self.typeOfIndex(inst);

        var payload = try self.wip.extractValue(result, &.{0}, "");
        if (llvm_abi_ty != .none) payload = try self.wip.cast(.trunc, payload, llvm_operand_ty, "");
        const success_bit = try self.wip.extractValue(result, &.{1}, "");

        if (optional_ty.optionalReprIsPayload(mod)) {
            const zero = try o.builder.zeroInitValue(payload.typeOfWip(&self.wip));
            return self.wip.select(.normal, success_bit, zero, payload, "");
        }

        comptime assert(optional_layout_version == 3);

        const non_null_bit = try self.wip.not(success_bit, "");
        return buildOptional(self, optional_ty, payload, non_null_bit);
    }

    fn airAtomicRmw(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;
        const ptr = try self.resolveInst(pl_op.operand);
        const ptr_ty = self.typeOf(pl_op.operand);
        const operand_ty = ptr_ty.childType(mod);
        const operand = try self.resolveInst(extra.operand);
        const is_signed_int = operand_ty.isSignedInt(mod);
        const is_float = operand_ty.isRuntimeFloat();
        const op = toLlvmAtomicRmwBinOp(extra.op(), is_signed_int, is_float);
        const ordering = toLlvmAtomicOrdering(extra.ordering());
        const llvm_abi_ty = try o.getAtomicAbiType(operand_ty, op == .xchg);
        const llvm_operand_ty = try o.lowerType(operand_ty);

        const access_kind: Builder.MemoryAccessKind =
            if (ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal;
        const ptr_alignment = ptr_ty.ptrAlignment(mod).toLlvm();

        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating or bitcasting.
            return self.wip.cast(if (is_float) .bitcast else .trunc, try self.wip.atomicrmw(
                access_kind,
                op,
                ptr,
                try self.wip.cast(
                    if (is_float) .bitcast else if (is_signed_int) .sext else .zext,
                    operand,
                    llvm_abi_ty,
                    "",
                ),
                self.sync_scope,
                ordering,
                ptr_alignment,
                "",
            ), llvm_operand_ty, "");
        }

        if (!llvm_operand_ty.isPointer(&o.builder)) return self.wip.atomicrmw(
            access_kind,
            op,
            ptr,
            operand,
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        );

        // It's a pointer but we need to treat it as an int.
        return self.wip.cast(.inttoptr, try self.wip.atomicrmw(
            access_kind,
            op,
            ptr,
            try self.wip.cast(.ptrtoint, operand, try o.lowerType(Type.usize), ""),
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        ), llvm_operand_ty, "");
    }

    fn airAtomicLoad(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const atomic_load = self.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;
        const ptr = try self.resolveInst(atomic_load.ptr);
        const ptr_ty = self.typeOf(atomic_load.ptr);
        const info = ptr_ty.ptrInfo(mod);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) return .none;
        const ordering = toLlvmAtomicOrdering(atomic_load.order);
        const llvm_abi_ty = try o.getAtomicAbiType(elem_ty, false);
        const ptr_alignment = (if (info.flags.alignment != .none)
            @as(InternPool.Alignment, info.flags.alignment)
        else
            Type.fromInterned(info.child).abiAlignment(mod)).toLlvm();
        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;
        const elem_llvm_ty = try o.lowerType(elem_ty);

        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating
            const loaded = try self.wip.loadAtomic(
                access_kind,
                llvm_abi_ty,
                ptr,
                self.sync_scope,
                ordering,
                ptr_alignment,
                "",
            );
            return self.wip.cast(.trunc, loaded, elem_llvm_ty, "");
        }
        return self.wip.loadAtomic(
            access_kind,
            elem_llvm_ty,
            ptr,
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        );
    }

    fn airAtomicStore(
        self: *FuncGen,
        inst: Air.Inst.Index,
        ordering: Builder.AtomicOrdering,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType(mod);
        if (!operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) return .none;
        const ptr = try self.resolveInst(bin_op.lhs);
        var element = try self.resolveInst(bin_op.rhs);
        const llvm_abi_ty = try o.getAtomicAbiType(operand_ty, false);

        if (llvm_abi_ty != .none) {
            // operand needs widening
            element = try self.wip.conv(
                if (operand_ty.isSignedInt(mod)) .signed else .unsigned,
                element,
                llvm_abi_ty,
                "",
            );
        }
        try self.store(ptr, ptr_ty, element, ordering);
        return .none;
    }

    fn airMemset(self: *FuncGen, inst: Air.Inst.Index, safety: bool) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_slice = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = self.typeOf(bin_op.rhs);
        const dest_ptr_align = ptr_ty.ptrAlignment(mod).toLlvm();
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, ptr_ty);
        const access_kind: Builder.MemoryAccessKind =
            if (ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal;

        // Any WebAssembly runtime will trap when the destination pointer is out-of-bounds, regardless
        // of the length. This means we need to emit a check where we skip the memset when the length
        // is 0 as we allow for undefined pointers in 0-sized slices.
        // This logic can be removed once https://github.com/ziglang/zig/issues/16360 is done.
        const intrinsic_len0_traps = o.target.isWasm() and
            ptr_ty.isSlice(mod) and
            std.Target.wasm.featureSetHas(o.target.cpu.features, .bulk_memory);

        if (try self.air.value(bin_op.rhs, mod)) |elem_val| {
            if (elem_val.isUndefDeep(mod)) {
                // Even if safety is disabled, we still emit a memset to undefined since it conveys
                // extra information to LLVM. However, safety makes the difference between using
                // 0xaa or actual undefined for the fill byte.
                const fill_byte = if (safety)
                    try o.builder.intValue(.i8, 0xaa)
                else
                    try o.builder.undefValue(.i8);
                const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);
                if (intrinsic_len0_traps) {
                    try self.safeWasmMemset(dest_ptr, fill_byte, len, dest_ptr_align, access_kind);
                } else {
                    _ = try self.wip.callMemSet(dest_ptr, dest_ptr_align, fill_byte, len, access_kind);
                }
                const owner_mod = self.dg.ownerModule();
                if (safety and owner_mod.valgrind) {
                    try self.valgrindMarkUndef(dest_ptr, len);
                }
                return .none;
            }

            // Test if the element value is compile-time known to be a
            // repeating byte pattern, for example, `@as(u64, 0)` has a
            // repeating byte pattern of 0 bytes. In such case, the memset
            // intrinsic can be used.
            if (try elem_val.hasRepeatedByteRepr(elem_ty, mod)) |byte_val| {
                const fill_byte = try o.builder.intValue(.i8, byte_val);
                const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);
                if (intrinsic_len0_traps) {
                    try self.safeWasmMemset(dest_ptr, fill_byte, len, dest_ptr_align, access_kind);
                } else {
                    _ = try self.wip.callMemSet(dest_ptr, dest_ptr_align, fill_byte, len, access_kind);
                }
                return .none;
            }
        }

        const value = try self.resolveInst(bin_op.rhs);
        const elem_abi_size = elem_ty.abiSize(mod);

        if (elem_abi_size == 1) {
            // In this case we can take advantage of LLVM's intrinsic.
            const fill_byte = try self.bitCast(value, elem_ty, Type.u8);
            const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);

            if (intrinsic_len0_traps) {
                try self.safeWasmMemset(dest_ptr, fill_byte, len, dest_ptr_align, access_kind);
            } else {
                _ = try self.wip.callMemSet(dest_ptr, dest_ptr_align, fill_byte, len, access_kind);
            }
            return .none;
        }

        // non-byte-sized element. lower with a loop. something like this:

        // entry:
        //   ...
        //   %end_ptr = getelementptr %ptr, %len
        //   br %loop
        // loop:
        //   %it_ptr = phi body %next_ptr, entry %ptr
        //   %end = cmp eq %it_ptr, %end_ptr
        //   br %end, %body, %end
        // body:
        //   store %it_ptr, %value
        //   %next_ptr = getelementptr %it_ptr, 1
        //   br %loop
        // end:
        //   ...
        const entry_block = self.wip.cursor.block;
        const loop_block = try self.wip.block(2, "InlineMemsetLoop");
        const body_block = try self.wip.block(1, "InlineMemsetBody");
        const end_block = try self.wip.block(1, "InlineMemsetEnd");

        const llvm_usize_ty = try o.lowerType(Type.usize);
        const len = switch (ptr_ty.ptrSize(mod)) {
            .Slice => try self.wip.extractValue(dest_slice, &.{1}, ""),
            .One => try o.builder.intValue(llvm_usize_ty, ptr_ty.childType(mod).arrayLen(mod)),
            .Many, .C => unreachable,
        };
        const elem_llvm_ty = try o.lowerType(elem_ty);
        const end_ptr = try self.wip.gep(.inbounds, elem_llvm_ty, dest_ptr, &.{len}, "");
        _ = try self.wip.br(loop_block);

        self.wip.cursor = .{ .block = loop_block };
        const it_ptr = try self.wip.phi(.ptr, "");
        const end = try self.wip.icmp(.ne, it_ptr.toValue(), end_ptr, "");
        _ = try self.wip.brCond(end, body_block, end_block);

        self.wip.cursor = .{ .block = body_block };
        const elem_abi_align = elem_ty.abiAlignment(mod);
        const it_ptr_align = InternPool.Alignment.fromLlvm(dest_ptr_align).min(elem_abi_align).toLlvm();
        if (isByRef(elem_ty, mod)) {
            _ = try self.wip.callMemCpy(
                it_ptr.toValue(),
                it_ptr_align,
                value,
                elem_abi_align.toLlvm(),
                try o.builder.intValue(llvm_usize_ty, elem_abi_size),
                access_kind,
            );
        } else _ = try self.wip.store(access_kind, value, it_ptr.toValue(), it_ptr_align);
        const next_ptr = try self.wip.gep(.inbounds, elem_llvm_ty, it_ptr.toValue(), &.{
            try o.builder.intValue(llvm_usize_ty, 1),
        }, "");
        _ = try self.wip.br(loop_block);

        self.wip.cursor = .{ .block = end_block };
        try it_ptr.finish(&.{ next_ptr, dest_ptr }, &.{ body_block, entry_block }, &self.wip);
        return .none;
    }

    fn safeWasmMemset(
        self: *FuncGen,
        dest_ptr: Builder.Value,
        fill_byte: Builder.Value,
        len: Builder.Value,
        dest_ptr_align: Builder.Alignment,
        access_kind: Builder.MemoryAccessKind,
    ) !void {
        const o = self.dg.object;
        const usize_zero = try o.builder.intValue(try o.lowerType(Type.usize), 0);
        const cond = try self.cmp(.normal, .neq, Type.usize, len, usize_zero);
        const memset_block = try self.wip.block(1, "MemsetTrapSkip");
        const end_block = try self.wip.block(2, "MemsetTrapEnd");
        _ = try self.wip.brCond(cond, memset_block, end_block);
        self.wip.cursor = .{ .block = memset_block };
        _ = try self.wip.callMemSet(dest_ptr, dest_ptr_align, fill_byte, len, access_kind);
        _ = try self.wip.br(end_block);
        self.wip.cursor = .{ .block = end_block };
    }

    fn airMemcpy(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_slice = try self.resolveInst(bin_op.lhs);
        const dest_ptr_ty = self.typeOf(bin_op.lhs);
        const src_slice = try self.resolveInst(bin_op.rhs);
        const src_ptr_ty = self.typeOf(bin_op.rhs);
        const src_ptr = try self.sliceOrArrayPtr(src_slice, src_ptr_ty);
        const len = try self.sliceOrArrayLenInBytes(dest_slice, dest_ptr_ty);
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, dest_ptr_ty);
        const access_kind: Builder.MemoryAccessKind = if (src_ptr_ty.isVolatilePtr(mod) or
            dest_ptr_ty.isVolatilePtr(mod)) .@"volatile" else .normal;

        // When bulk-memory is enabled, this will be lowered to WebAssembly's memory.copy instruction.
        // This instruction will trap on an invalid address, regardless of the length.
        // For this reason we must add a check for 0-sized slices as its pointer field can be undefined.
        // We only have to do this for slices as arrays will have a valid pointer.
        // This logic can be removed once https://github.com/ziglang/zig/issues/16360 is done.
        if (o.target.isWasm() and
            std.Target.wasm.featureSetHas(o.target.cpu.features, .bulk_memory) and
            dest_ptr_ty.isSlice(mod))
        {
            const usize_zero = try o.builder.intValue(try o.lowerType(Type.usize), 0);
            const cond = try self.cmp(.normal, .neq, Type.usize, len, usize_zero);
            const memcpy_block = try self.wip.block(1, "MemcpyTrapSkip");
            const end_block = try self.wip.block(2, "MemcpyTrapEnd");
            _ = try self.wip.brCond(cond, memcpy_block, end_block);
            self.wip.cursor = .{ .block = memcpy_block };
            _ = try self.wip.callMemCpy(
                dest_ptr,
                dest_ptr_ty.ptrAlignment(mod).toLlvm(),
                src_ptr,
                src_ptr_ty.ptrAlignment(mod).toLlvm(),
                len,
                access_kind,
            );
            _ = try self.wip.br(end_block);
            self.wip.cursor = .{ .block = end_block };
            return .none;
        }

        _ = try self.wip.callMemCpy(
            dest_ptr,
            dest_ptr_ty.ptrAlignment(mod).toLlvm(),
            src_ptr,
            src_ptr_ty.ptrAlignment(mod).toLlvm(),
            len,
            access_kind,
        );
        return .none;
    }

    fn airSetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const un_ty = self.typeOf(bin_op.lhs).childType(mod);
        const layout = un_ty.unionGetLayout(mod);
        if (layout.tag_size == 0) return .none;
        const union_ptr = try self.resolveInst(bin_op.lhs);
        const new_tag = try self.resolveInst(bin_op.rhs);
        if (layout.payload_size == 0) {
            // TODO alignment on this store
            _ = try self.wip.store(.normal, new_tag, union_ptr, .default);
            return .none;
        }
        const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
        const tag_field_ptr = try self.wip.gepStruct(try o.lowerType(un_ty), union_ptr, tag_index, "");
        // TODO alignment on this store
        _ = try self.wip.store(.normal, new_tag, tag_field_ptr, .default);
        return .none;
    }

    fn airGetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const un_ty = self.typeOf(ty_op.operand);
        const layout = un_ty.unionGetLayout(mod);
        if (layout.tag_size == 0) return .none;
        const union_handle = try self.resolveInst(ty_op.operand);
        if (isByRef(un_ty, mod)) {
            const llvm_un_ty = try o.lowerType(un_ty);
            if (layout.payload_size == 0)
                return self.wip.load(.normal, llvm_un_ty, union_handle, .default, "");
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            const tag_field_ptr = try self.wip.gepStruct(llvm_un_ty, union_handle, tag_index, "");
            const llvm_tag_ty = llvm_un_ty.structFields(&o.builder)[tag_index];
            return self.wip.load(.normal, llvm_tag_ty, tag_field_ptr, .default, "");
        } else {
            if (layout.payload_size == 0) return union_handle;
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            return self.wip.extractValue(union_handle, &.{tag_index}, "");
        }
    }

    fn airUnaryOp(self: *FuncGen, inst: Air.Inst.Index, comptime op: FloatOp) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);

        return self.buildFloatOp(op, .normal, operand_ty, 1, .{operand});
    }

    fn airNeg(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);

        return self.buildFloatOp(.neg, fast, operand_ty, 1, .{operand});
    }

    fn airClzCtz(self: *FuncGen, inst: Air.Inst.Index, intrinsic: Builder.Intrinsic) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            intrinsic,
            &.{try o.lowerType(operand_ty)},
            &.{ operand, .false },
            "",
        );
        return self.wip.conv(.unsigned, result, try o.lowerType(inst_ty), "");
    }

    fn airBitOp(self: *FuncGen, inst: Air.Inst.Index, intrinsic: Builder.Intrinsic) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            intrinsic,
            &.{try o.lowerType(operand_ty)},
            &.{operand},
            "",
        );
        return self.wip.conv(.unsigned, result, try o.lowerType(inst_ty), "");
    }

    fn airByteSwap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        var bits = operand_ty.intInfo(mod).bits;
        assert(bits % 8 == 0);

        const inst_ty = self.typeOfIndex(inst);
        var operand = try self.resolveInst(ty_op.operand);
        var llvm_operand_ty = try o.lowerType(operand_ty);

        if (bits % 16 == 8) {
            // If not an even byte-multiple, we need zero-extend + shift-left 1 byte
            // The truncated result at the end will be the correct bswap
            const scalar_ty = try o.builder.intType(@intCast(bits + 8));
            if (operand_ty.zigTypeTag(mod) == .Vector) {
                const vec_len = operand_ty.vectorLen(mod);
                llvm_operand_ty = try o.builder.vectorType(.normal, vec_len, scalar_ty);
            } else llvm_operand_ty = scalar_ty;

            const shift_amt =
                try o.builder.splatValue(llvm_operand_ty, try o.builder.intConst(scalar_ty, 8));
            const extended = try self.wip.cast(.zext, operand, llvm_operand_ty, "");
            operand = try self.wip.bin(.shl, extended, shift_amt, "");

            bits = bits + 8;
        }

        const result =
            try self.wip.callIntrinsic(.normal, .none, .bswap, &.{llvm_operand_ty}, &.{operand}, "");
        return self.wip.conv(.unsigned, result, try o.lowerType(inst_ty), "");
    }

    fn airErrorSetHasValue(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const error_set_ty = ty_op.ty.toType();

        const names = error_set_ty.errorSetNames(mod);
        const valid_block = try self.wip.block(@intCast(names.len), "Valid");
        const invalid_block = try self.wip.block(1, "Invalid");
        const end_block = try self.wip.block(2, "End");
        var wip_switch = try self.wip.@"switch"(operand, invalid_block, @intCast(names.len));
        defer wip_switch.finish(&self.wip);

        for (names) |name| {
            const err_int = mod.global_error_set.getIndex(name).?;
            const this_tag_int_value = try o.builder.intConst(try o.errorIntType(), err_int);
            try wip_switch.addCase(this_tag_int_value, valid_block, &self.wip);
        }
        self.wip.cursor = .{ .block = valid_block };
        _ = try self.wip.br(end_block);

        self.wip.cursor = .{ .block = invalid_block };
        _ = try self.wip.br(end_block);

        self.wip.cursor = .{ .block = end_block };
        const phi = try self.wip.phi(.i1, "");
        try phi.finish(&.{ .true, .false }, &.{ valid_block, invalid_block }, &self.wip);
        return phi.toValue();
    }

    fn airIsNamedEnumValue(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const enum_ty = self.typeOf(un_op);

        const llvm_fn = try self.getIsNamedEnumValueFunction(enum_ty);
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn getIsNamedEnumValueFunction(self: *FuncGen, enum_ty: Type) !Builder.Function.Index {
        const o = self.dg.object;
        const zcu = o.module;
        const enum_type = zcu.intern_pool.indexToKey(enum_ty.toIntern()).enum_type;

        // TODO: detect when the type changes and re-emit this function.
        const gop = try o.named_enum_map.getOrPut(o.gpa, enum_type.decl);
        if (gop.found_existing) return gop.value_ptr.*;
        errdefer assert(o.named_enum_map.remove(enum_type.decl));

        const fqn = try zcu.declPtr(enum_type.decl).getFullyQualifiedName(zcu);
        const target = zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(.i1, &.{try o.lowerType(Type.fromInterned(enum_type.tag_ty))}, .normal),
            try o.builder.fmt("__zig_is_named_enum_value_{}", .{fqn.fmt(&zcu.intern_pool)}),
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        gop.value_ptr.* = function_index;

        var wip = try Builder.WipFunction.init(&o.builder, function_index);
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        const named_block = try wip.block(@intCast(enum_type.names.len), "Named");
        const unnamed_block = try wip.block(1, "Unnamed");
        const tag_int_value = wip.arg(0);
        var wip_switch = try wip.@"switch"(tag_int_value, unnamed_block, @intCast(enum_type.names.len));
        defer wip_switch.finish(&wip);

        for (0..enum_type.names.len) |field_index| {
            const this_tag_int_value = try o.lowerValue(
                (try zcu.enumValueFieldIndex(enum_ty, @intCast(field_index))).toIntern(),
            );
            try wip_switch.addCase(this_tag_int_value, named_block, &wip);
        }
        wip.cursor = .{ .block = named_block };
        _ = try wip.ret(.true);

        wip.cursor = .{ .block = unnamed_block };
        _ = try wip.ret(.false);

        try wip.finish();
        return function_index;
    }

    fn airTagName(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const enum_ty = self.typeOf(un_op);

        const llvm_fn = try o.getEnumTagNameFunction(enum_ty);
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn airErrorName(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const slice_ty = self.typeOfIndex(inst);
        const slice_llvm_ty = try o.lowerType(slice_ty);

        const error_name_table_ptr = try self.getErrorNameTable();
        const error_name_table =
            try self.wip.load(.normal, .ptr, error_name_table_ptr.toValue(&o.builder), .default, "");
        const error_name_ptr =
            try self.wip.gep(.inbounds, slice_llvm_ty, error_name_table, &.{operand}, "");
        return self.wip.load(.normal, slice_llvm_ty, error_name_ptr, .default, "");
    }

    fn airSplat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const scalar = try self.resolveInst(ty_op.operand);
        const vector_ty = self.typeOfIndex(inst);
        return self.wip.splatVector(try o.lowerType(vector_ty), scalar, "");
    }

    fn airSelect(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
        const pred = try self.resolveInst(pl_op.operand);
        const a = try self.resolveInst(extra.lhs);
        const b = try self.resolveInst(extra.rhs);

        return self.wip.select(.normal, pred, a, b, "");
    }

    fn airShuffle(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
        const a = try self.resolveInst(extra.a);
        const b = try self.resolveInst(extra.b);
        const mask = Value.fromInterned(extra.mask);
        const mask_len = extra.mask_len;
        const a_len = self.typeOf(extra.a).vectorLen(mod);

        // LLVM uses integers larger than the length of the first array to
        // index into the second array. This was deemed unnecessarily fragile
        // when changing code, so Zig uses negative numbers to index the
        // second vector. These start at -1 and go down, and are easiest to use
        // with the ~ operator. Here we convert between the two formats.
        const values = try self.gpa.alloc(Builder.Constant, mask_len);
        defer self.gpa.free(values);

        for (values, 0..) |*val, i| {
            const elem = try mask.elemValue(mod, i);
            if (elem.isUndef(mod)) {
                val.* = try o.builder.undefConst(.i32);
            } else {
                const int = elem.toSignedInt(mod);
                const unsigned: u32 = @intCast(if (int >= 0) int else ~int + a_len);
                val.* = try o.builder.intConst(.i32, unsigned);
            }
        }

        const llvm_mask_value = try o.builder.vectorValue(
            try o.builder.vectorType(.normal, mask_len, .i32),
            values,
        );
        return self.wip.shuffleVector(a, b, llvm_mask_value, "");
    }

    /// Reduce a vector by repeatedly applying `llvm_fn` to produce an accumulated result.
    ///
    /// Equivalent to:
    ///   reduce: {
    ///     var i: usize = 0;
    ///     var accum: T = init;
    ///     while (i < vec.len) : (i += 1) {
    ///       accum = llvm_fn(accum, vec[i]);
    ///     }
    ///     break :reduce accum;
    ///   }
    ///
    fn buildReducedCall(
        self: *FuncGen,
        llvm_fn: Builder.Function.Index,
        operand_vector: Builder.Value,
        vector_len: usize,
        accum_init: Builder.Value,
    ) !Builder.Value {
        const o = self.dg.object;
        const usize_ty = try o.lowerType(Type.usize);
        const llvm_vector_len = try o.builder.intValue(usize_ty, vector_len);
        const llvm_result_ty = accum_init.typeOfWip(&self.wip);

        // Allocate and initialize our mutable variables
        const i_ptr = try self.buildAllocaWorkaround(Type.usize, .default);
        _ = try self.wip.store(.normal, try o.builder.intValue(usize_ty, 0), i_ptr, .default);
        const accum_ptr = try self.buildAlloca(llvm_result_ty, .default);
        _ = try self.wip.store(.normal, accum_init, accum_ptr, .default);

        // Setup the loop
        const loop = try self.wip.block(2, "ReduceLoop");
        const loop_exit = try self.wip.block(1, "AfterReduce");
        _ = try self.wip.br(loop);
        {
            self.wip.cursor = .{ .block = loop };

            // while (i < vec.len)
            const i = try self.wip.load(.normal, usize_ty, i_ptr, .default, "");
            const cond = try self.wip.icmp(.ult, i, llvm_vector_len, "");
            const loop_then = try self.wip.block(1, "ReduceLoopThen");

            _ = try self.wip.brCond(cond, loop_then, loop_exit);

            {
                self.wip.cursor = .{ .block = loop_then };

                // accum = f(accum, vec[i]);
                const accum = try self.wip.load(.normal, llvm_result_ty, accum_ptr, .default, "");
                const element = try self.wip.extractElement(operand_vector, i, "");
                const new_accum = try self.wip.call(
                    .normal,
                    .ccc,
                    .none,
                    llvm_fn.typeOf(&o.builder),
                    llvm_fn.toValue(&o.builder),
                    &.{ accum, element },
                    "",
                );
                _ = try self.wip.store(.normal, new_accum, accum_ptr, .default);

                // i += 1
                const new_i = try self.wip.bin(.add, i, try o.builder.intValue(usize_ty, 1), "");
                _ = try self.wip.store(.normal, new_i, i_ptr, .default);
                _ = try self.wip.br(loop);
            }
        }

        self.wip.cursor = .{ .block = loop_exit };
        return self.wip.load(.normal, llvm_result_ty, accum_ptr, .default, "");
    }

    fn airReduce(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const target = mod.getTarget();

        const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
        const operand = try self.resolveInst(reduce.operand);
        const operand_ty = self.typeOf(reduce.operand);
        const llvm_operand_ty = try o.lowerType(operand_ty);
        const scalar_ty = self.typeOfIndex(inst);
        const llvm_scalar_ty = try o.lowerType(scalar_ty);

        switch (reduce.operation) {
            .And, .Or, .Xor => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                .And => .@"vector.reduce.and",
                .Or => .@"vector.reduce.or",
                .Xor => .@"vector.reduce.xor",
                else => unreachable,
            }, &.{llvm_operand_ty}, &.{operand}, ""),
            .Min, .Max => switch (scalar_ty.zigTypeTag(mod)) {
                .Int => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                    .Min => if (scalar_ty.isSignedInt(mod))
                        .@"vector.reduce.smin"
                    else
                        .@"vector.reduce.umin",
                    .Max => if (scalar_ty.isSignedInt(mod))
                        .@"vector.reduce.smax"
                    else
                        .@"vector.reduce.umax",
                    else => unreachable,
                }, &.{llvm_operand_ty}, &.{operand}, ""),
                .Float => if (intrinsicsAllowed(scalar_ty, target))
                    return self.wip.callIntrinsic(fast, .none, switch (reduce.operation) {
                        .Min => .@"vector.reduce.fmin",
                        .Max => .@"vector.reduce.fmax",
                        else => unreachable,
                    }, &.{llvm_operand_ty}, &.{operand}, ""),
                else => unreachable,
            },
            .Add, .Mul => switch (scalar_ty.zigTypeTag(mod)) {
                .Int => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                    .Add => .@"vector.reduce.add",
                    .Mul => .@"vector.reduce.mul",
                    else => unreachable,
                }, &.{llvm_operand_ty}, &.{operand}, ""),
                .Float => if (intrinsicsAllowed(scalar_ty, target))
                    return self.wip.callIntrinsic(fast, .none, switch (reduce.operation) {
                        .Add => .@"vector.reduce.fadd",
                        .Mul => .@"vector.reduce.fmul",
                        else => unreachable,
                    }, &.{llvm_operand_ty}, &.{ switch (reduce.operation) {
                        .Add => try o.builder.fpValue(llvm_scalar_ty, -0.0),
                        .Mul => try o.builder.fpValue(llvm_scalar_ty, 1.0),
                        else => unreachable,
                    }, operand }, ""),
                else => unreachable,
            },
        }

        // Reduction could not be performed with intrinsics.
        // Use a manual loop over a softfloat call instead.
        const float_bits = scalar_ty.floatBits(target);
        const fn_name = switch (reduce.operation) {
            .Min => try o.builder.fmt("{s}fmin{s}", .{
                libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
            }),
            .Max => try o.builder.fmt("{s}fmax{s}", .{
                libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
            }),
            .Add => try o.builder.fmt("__add{s}f3", .{
                compilerRtFloatAbbrev(float_bits),
            }),
            .Mul => try o.builder.fmt("__mul{s}f3", .{
                compilerRtFloatAbbrev(float_bits),
            }),
            else => unreachable,
        };

        const libc_fn =
            try self.getLibcFunction(fn_name, &.{ llvm_scalar_ty, llvm_scalar_ty }, llvm_scalar_ty);
        const init_val = switch (llvm_scalar_ty) {
            .i16 => try o.builder.intValue(.i16, @as(i16, @bitCast(
                @as(f16, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f16),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            .i80 => try o.builder.intValue(.i80, @as(i80, @bitCast(
                @as(f80, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f80),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            .i128 => try o.builder.intValue(.i128, @as(i128, @bitCast(
                @as(f128, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f128),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            else => unreachable,
        };
        return self.buildReducedCall(libc_fn, operand, operand_ty.vectorLen(mod), init_val);
    }

    fn airAggregateInit(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const result_ty = self.typeOfIndex(inst);
        const len: usize = @intCast(result_ty.arrayLen(mod));
        const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);
        const llvm_result_ty = try o.lowerType(result_ty);

        switch (result_ty.zigTypeTag(mod)) {
            .Vector => {
                var vector = try o.builder.poisonValue(llvm_result_ty);
                for (elements, 0..) |elem, i| {
                    const index_u32 = try o.builder.intValue(.i32, i);
                    const llvm_elem = try self.resolveInst(elem);
                    vector = try self.wip.insertElement(vector, llvm_elem, index_u32, "");
                }
                return vector;
            },
            .Struct => {
                if (mod.typeToPackedStruct(result_ty)) |struct_type| {
                    const backing_int_ty = struct_type.backingIntType(ip).*;
                    assert(backing_int_ty != .none);
                    const big_bits = Type.fromInterned(backing_int_ty).bitSize(mod);
                    const int_ty = try o.builder.intType(@intCast(big_bits));
                    comptime assert(Type.packed_struct_layout_version == 2);
                    var running_int = try o.builder.intValue(int_ty, 0);
                    var running_bits: u16 = 0;
                    for (elements, struct_type.field_types.get(ip)) |elem, field_ty| {
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) continue;

                        const non_int_val = try self.resolveInst(elem);
                        const ty_bit_size: u16 = @intCast(Type.fromInterned(field_ty).bitSize(mod));
                        const small_int_ty = try o.builder.intType(ty_bit_size);
                        const small_int_val = if (Type.fromInterned(field_ty).isPtrAtRuntime(mod))
                            try self.wip.cast(.ptrtoint, non_int_val, small_int_ty, "")
                        else
                            try self.wip.cast(.bitcast, non_int_val, small_int_ty, "");
                        const shift_rhs = try o.builder.intValue(int_ty, running_bits);
                        const extended_int_val =
                            try self.wip.conv(.unsigned, small_int_val, int_ty, "");
                        const shifted = try self.wip.bin(.shl, extended_int_val, shift_rhs, "");
                        running_int = try self.wip.bin(.@"or", running_int, shifted, "");
                        running_bits += ty_bit_size;
                    }
                    return running_int;
                }

                assert(result_ty.containerLayout(mod) != .Packed);

                if (isByRef(result_ty, mod)) {
                    // TODO in debug builds init to undef so that the padding will be 0xaa
                    // even if we fully populate the fields.
                    const alignment = result_ty.abiAlignment(mod).toLlvm();
                    const alloca_inst = try self.buildAllocaWorkaround(result_ty, alignment);

                    for (elements, 0..) |elem, i| {
                        if ((try result_ty.structFieldValueComptime(mod, i)) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = o.llvmFieldIndex(result_ty, i).?;
                        const field_ptr =
                            try self.wip.gepStruct(llvm_result_ty, alloca_inst, llvm_i, "");
                        const field_ptr_ty = try mod.ptrType(.{
                            .child = self.typeOf(elem).toIntern(),
                            .flags = .{
                                .alignment = result_ty.structFieldAlign(i, mod),
                            },
                        });
                        try self.store(field_ptr, field_ptr_ty, llvm_elem, .none);
                    }

                    return alloca_inst;
                } else {
                    var result = try o.builder.poisonValue(llvm_result_ty);
                    for (elements, 0..) |elem, i| {
                        if ((try result_ty.structFieldValueComptime(mod, i)) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = o.llvmFieldIndex(result_ty, i).?;
                        result = try self.wip.insertValue(result, llvm_elem, &.{llvm_i}, "");
                    }
                    return result;
                }
            },
            .Array => {
                assert(isByRef(result_ty, mod));

                const llvm_usize = try o.lowerType(Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const alignment = result_ty.abiAlignment(mod).toLlvm();
                const alloca_inst = try self.buildAllocaWorkaround(result_ty, alignment);

                const array_info = result_ty.arrayInfo(mod);
                const elem_ptr_ty = try mod.ptrType(.{
                    .child = array_info.elem_type.toIntern(),
                });

                for (elements, 0..) |elem, i| {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_result_ty, alloca_inst, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const llvm_elem = try self.resolveInst(elem);
                    try self.store(elem_ptr, elem_ptr_ty, llvm_elem, .none);
                }
                if (array_info.sentinel) |sent_val| {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_result_ty, alloca_inst, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, array_info.len),
                    }, "");
                    const llvm_elem = try self.resolveValue(.{
                        .ty = array_info.elem_type,
                        .val = sent_val,
                    });
                    try self.store(elem_ptr, elem_ptr_ty, llvm_elem.toValue(), .none);
                }

                return alloca_inst;
            },
            else => unreachable,
        }
    }

    fn airUnionInit(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const ip = &mod.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
        const union_ty = self.typeOfIndex(inst);
        const union_llvm_ty = try o.lowerType(union_ty);
        const layout = union_ty.unionGetLayout(mod);
        const union_obj = mod.typeToUnion(union_ty).?;

        if (union_obj.getLayout(ip) == .Packed) {
            const big_bits = union_ty.bitSize(mod);
            const int_llvm_ty = try o.builder.intType(@intCast(big_bits));
            const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
            const non_int_val = try self.resolveInst(extra.init);
            const small_int_ty = try o.builder.intType(@intCast(field_ty.bitSize(mod)));
            const small_int_val = if (field_ty.isPtrAtRuntime(mod))
                try self.wip.cast(.ptrtoint, non_int_val, small_int_ty, "")
            else
                try self.wip.cast(.bitcast, non_int_val, small_int_ty, "");
            return self.wip.conv(.unsigned, small_int_val, int_llvm_ty, "");
        }

        const tag_int = blk: {
            const tag_ty = union_ty.unionTagTypeHypothetical(mod);
            const union_field_name = union_obj.field_names.get(ip)[extra.field_index];
            const enum_field_index = tag_ty.enumFieldIndex(union_field_name, mod).?;
            const tag_val = try mod.enumValueFieldIndex(tag_ty, enum_field_index);
            const tag_int_val = try tag_val.intFromEnum(tag_ty, mod);
            break :blk tag_int_val.toUnsignedInt(mod);
        };
        if (layout.payload_size == 0) {
            if (layout.tag_size == 0) {
                return .none;
            }
            assert(!isByRef(union_ty, mod));
            return o.builder.intValue(union_llvm_ty, tag_int);
        }
        assert(isByRef(union_ty, mod));
        // The llvm type of the alloca will be the named LLVM union type, and will not
        // necessarily match the format that we need, depending on which tag is active.
        // We must construct the correct unnamed struct type here, in order to then set
        // the fields appropriately.
        const alignment = layout.abi_align.toLlvm();
        const result_ptr = try self.buildAllocaWorkaround(union_ty, alignment);
        const llvm_payload = try self.resolveInst(extra.init);
        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
        const field_llvm_ty = try o.lowerType(field_ty);
        const field_size = field_ty.abiSize(mod);
        const field_align = mod.unionFieldNormalAlignment(union_obj, extra.field_index);
        const llvm_usize = try o.lowerType(Type.usize);
        const usize_zero = try o.builder.intValue(llvm_usize, 0);
        const i32_zero = try o.builder.intValue(.i32, 0);

        const llvm_union_ty = t: {
            const payload_ty = p: {
                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    const padding_len = layout.payload_size;
                    break :p try o.builder.arrayType(padding_len, .i8);
                }
                if (field_size == layout.payload_size) {
                    break :p field_llvm_ty;
                }
                const padding_len = layout.payload_size - field_size;
                break :p try o.builder.structType(.@"packed", &.{
                    field_llvm_ty, try o.builder.arrayType(padding_len, .i8),
                });
            };
            if (layout.tag_size == 0) break :t try o.builder.structType(.normal, &.{payload_ty});
            const tag_ty = try o.lowerType(Type.fromInterned(union_obj.enum_tag_ty));
            var fields: [3]Builder.Type = undefined;
            var fields_len: usize = 2;
            if (layout.tag_align.compare(.gte, layout.payload_align)) {
                fields = .{ tag_ty, payload_ty, undefined };
            } else {
                fields = .{ payload_ty, tag_ty, undefined };
            }
            if (layout.padding != 0) {
                fields[fields_len] = try o.builder.arrayType(layout.padding, .i8);
                fields_len += 1;
            }
            break :t try o.builder.structType(.normal, fields[0..fields_len]);
        };

        // Now we follow the layout as expressed above with GEP instructions to set the
        // tag and the payload.
        const field_ptr_ty = try mod.ptrType(.{
            .child = field_ty.toIntern(),
            .flags = .{ .alignment = field_align },
        });
        if (layout.tag_size == 0) {
            const indices = [3]Builder.Value{ usize_zero, i32_zero, i32_zero };
            const len: usize = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr =
                try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, indices[0..len], "");
            try self.store(field_ptr, field_ptr_ty, llvm_payload, .none);
            return result_ptr;
        }

        {
            const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
            const indices: [3]Builder.Value =
                .{ usize_zero, try o.builder.intValue(.i32, payload_index), i32_zero };
            const len: usize = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr =
                try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, indices[0..len], "");
            try self.store(field_ptr, field_ptr_ty, llvm_payload, .none);
        }
        {
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            const indices: [2]Builder.Value = .{ usize_zero, try o.builder.intValue(.i32, tag_index) };
            const field_ptr = try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, &indices, "");
            const tag_ty = try o.lowerType(Type.fromInterned(union_obj.enum_tag_ty));
            const llvm_tag = try o.builder.intValue(tag_ty, tag_int);
            const tag_alignment = Type.fromInterned(union_obj.enum_tag_ty).abiAlignment(mod).toLlvm();
            _ = try self.wip.store(.normal, llvm_tag, field_ptr, tag_alignment);
        }

        return result_ptr;
    }

    fn airPrefetch(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;

        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Rw.read) == 0);
        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Rw.write) == 1);

        // TODO these two asserts should be able to be comptime because the type is a u2
        assert(prefetch.locality >= 0);
        assert(prefetch.locality <= 3);

        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Cache.instruction) == 0);
        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Cache.data) == 1);

        // LLVM fails during codegen of instruction cache prefetchs for these architectures.
        // This is an LLVM bug as the prefetch intrinsic should be a noop if not supported
        // by the target.
        // To work around this, don't emit llvm.prefetch in this case.
        // See https://bugs.llvm.org/show_bug.cgi?id=21037
        const mod = o.module;
        const target = mod.getTarget();
        switch (prefetch.cache) {
            .instruction => switch (target.cpu.arch) {
                .x86_64,
                .x86,
                .powerpc,
                .powerpcle,
                .powerpc64,
                .powerpc64le,
                => return .none,
                .arm, .armeb, .thumb, .thumbeb => {
                    switch (prefetch.rw) {
                        .write => return .none,
                        else => {},
                    }
                },
                else => {},
            },
            .data => {},
        }

        _ = try self.wip.callIntrinsic(.normal, .none, .prefetch, &.{.ptr}, &.{
            try self.sliceOrArrayPtr(try self.resolveInst(prefetch.ptr), self.typeOf(prefetch.ptr)),
            try o.builder.intValue(.i32, prefetch.rw),
            try o.builder.intValue(.i32, prefetch.locality),
            try o.builder.intValue(.i32, prefetch.cache),
        }, "");
        return .none;
    }

    fn airAddrSpaceCast(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);

        return self.wip.cast(.addrspacecast, operand, try o.lowerType(inst_ty), "");
    }

    fn amdgcnWorkIntrinsic(
        self: *FuncGen,
        dimension: u32,
        default: u32,
        comptime basename: []const u8,
    ) !Builder.Value {
        return self.wip.callIntrinsic(.normal, .none, switch (dimension) {
            0 => @field(Builder.Intrinsic, basename ++ ".x"),
            1 => @field(Builder.Intrinsic, basename ++ ".y"),
            2 => @field(Builder.Intrinsic, basename ++ ".z"),
            else => return self.dg.object.builder.intValue(.i32, default),
        }, &.{}, &.{}, "");
    }

    fn airWorkItemId(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const target = o.module.getTarget();
        assert(target.cpu.arch == .amdgcn); // TODO is to port this function to other GPU architectures

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;
        return self.amdgcnWorkIntrinsic(dimension, 0, "amdgcn.workitem.id");
    }

    fn airWorkGroupSize(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const target = o.module.getTarget();
        assert(target.cpu.arch == .amdgcn); // TODO is to port this function to other GPU architectures

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;
        if (dimension >= 3) return o.builder.intValue(.i32, 1);

        // Fetch the dispatch pointer, which points to this structure:
        // https://github.com/RadeonOpenCompute/ROCR-Runtime/blob/adae6c61e10d371f7cbc3d0e94ae2c070cab18a4/src/inc/hsa.h#L2913
        const dispatch_ptr =
            try self.wip.callIntrinsic(.normal, .none, .@"amdgcn.dispatch.ptr", &.{}, &.{}, "");

        // Load the work_group_* member from the struct as u16.
        // Just treat the dispatch pointer as an array of u16 to keep things simple.
        const workgroup_size_ptr = try self.wip.gep(.inbounds, .i16, dispatch_ptr, &.{
            try o.builder.intValue(try o.lowerType(Type.usize), 2 + dimension),
        }, "");
        const workgroup_size_alignment = comptime Builder.Alignment.fromByteUnits(2);
        return self.wip.load(.normal, .i16, workgroup_size_ptr, workgroup_size_alignment, "");
    }

    fn airWorkGroupId(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.dg.object;
        const target = o.module.getTarget();
        assert(target.cpu.arch == .amdgcn); // TODO is to port this function to other GPU architectures

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;
        return self.amdgcnWorkIntrinsic(dimension, 0, "amdgcn.workgroup.id");
    }

    fn getErrorNameTable(self: *FuncGen) Allocator.Error!Builder.Variable.Index {
        const o = self.dg.object;
        const mod = o.module;

        const table = o.error_name_table;
        if (table != .none) return table;

        // TODO: Address space
        const variable_index =
            try o.builder.addVariable(try o.builder.string("__zig_err_name_table"), .ptr, .default);
        variable_index.setLinkage(.private, &o.builder);
        variable_index.setMutability(.constant, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(
            Type.slice_const_u8_sentinel_0.abiAlignment(mod).toLlvm(),
            &o.builder,
        );

        o.error_name_table = variable_index;
        return variable_index;
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optCmpNull(
        self: *FuncGen,
        cond: Builder.IntegerCondition,
        opt_llvm_ty: Builder.Type,
        opt_handle: Builder.Value,
        is_by_ref: bool,
    ) Allocator.Error!Builder.Value {
        const o = self.dg.object;
        const field = b: {
            if (is_by_ref) {
                const field_ptr = try self.wip.gepStruct(opt_llvm_ty, opt_handle, 1, "");
                break :b try self.wip.load(.normal, .i8, field_ptr, .default, "");
            }
            break :b try self.wip.extractValue(opt_handle, &.{1}, "");
        };
        comptime assert(optional_layout_version == 3);

        return self.wip.icmp(cond, field, try o.builder.intValue(.i8, 0), "");
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optPayloadHandle(
        fg: *FuncGen,
        opt_llvm_ty: Builder.Type,
        opt_handle: Builder.Value,
        opt_ty: Type,
        can_elide_load: bool,
    ) !Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        const payload_ty = opt_ty.optionalChild(mod);

        if (isByRef(opt_ty, mod)) {
            // We have a pointer and we need to return a pointer to the first field.
            const payload_ptr = try fg.wip.gepStruct(opt_llvm_ty, opt_handle, 0, "");

            const payload_alignment = payload_ty.abiAlignment(mod).toLlvm();
            if (isByRef(payload_ty, mod)) {
                if (can_elide_load)
                    return payload_ptr;

                return fg.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            return fg.loadTruncate(.normal, payload_ty, payload_ptr, payload_alignment);
        }

        assert(!isByRef(payload_ty, mod));
        return fg.wip.extractValue(opt_handle, &.{0}, "");
    }

    fn buildOptional(
        self: *FuncGen,
        optional_ty: Type,
        payload: Builder.Value,
        non_null_bit: Builder.Value,
    ) !Builder.Value {
        const o = self.dg.object;
        const optional_llvm_ty = try o.lowerType(optional_ty);
        const non_null_field = try self.wip.cast(.zext, non_null_bit, .i8, "");
        const mod = o.module;

        if (isByRef(optional_ty, mod)) {
            const payload_alignment = optional_ty.abiAlignment(mod).toLlvm();
            const alloca_inst = try self.buildAllocaWorkaround(optional_ty, payload_alignment);

            {
                const field_ptr = try self.wip.gepStruct(optional_llvm_ty, alloca_inst, 0, "");
                _ = try self.wip.store(.normal, payload, field_ptr, payload_alignment);
            }
            {
                const non_null_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(optional_llvm_ty, alloca_inst, 1, "");
                _ = try self.wip.store(.normal, non_null_field, field_ptr, non_null_alignment);
            }

            return alloca_inst;
        }

        return self.wip.buildAggregate(optional_llvm_ty, &.{ payload, non_null_field }, "");
    }

    fn fieldPtr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        struct_ptr: Builder.Value,
        struct_ptr_ty: Type,
        field_index: u32,
    ) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const struct_ty = struct_ptr_ty.childType(mod);
        switch (struct_ty.zigTypeTag(mod)) {
            .Struct => switch (struct_ty.containerLayout(mod)) {
                .Packed => {
                    const result_ty = self.typeOfIndex(inst);
                    const result_ty_info = result_ty.ptrInfo(mod);
                    const struct_ptr_ty_info = struct_ptr_ty.ptrInfo(mod);
                    const struct_type = mod.typeToStruct(struct_ty).?;

                    if (result_ty_info.packed_offset.host_size != 0) {
                        // From LLVM's perspective, a pointer to a packed struct and a pointer
                        // to a field of a packed struct are the same. The difference is in the
                        // Zig pointer type which provides information for how to mask and shift
                        // out the relevant bits when accessing the pointee.
                        return struct_ptr;
                    }

                    // We have a pointer to a packed struct field that happens to be byte-aligned.
                    // Offset our operand pointer by the correct number of bytes.
                    const byte_offset = @divExact(mod.structPackedFieldBitOffset(struct_type, field_index) + struct_ptr_ty_info.packed_offset.bit_offset, 8);
                    if (byte_offset == 0) return struct_ptr;
                    const usize_ty = try o.lowerType(Type.usize);
                    const llvm_index = try o.builder.intValue(usize_ty, byte_offset);
                    return self.wip.gep(.inbounds, .i8, struct_ptr, &.{llvm_index}, "");
                },
                else => {
                    const struct_llvm_ty = try o.lowerPtrElemTy(struct_ty);

                    if (o.llvmFieldIndex(struct_ty, field_index)) |llvm_field_index| {
                        return self.wip.gepStruct(struct_llvm_ty, struct_ptr, llvm_field_index, "");
                    } else {
                        // If we found no index then this means this is a zero sized field at the
                        // end of the struct. Treat our struct pointer as an array of two and get
                        // the index to the element at index `1` to get a pointer to the end of
                        // the struct.
                        const llvm_index = try o.builder.intValue(
                            try o.lowerType(Type.usize),
                            @intFromBool(struct_ty.hasRuntimeBitsIgnoreComptime(mod)),
                        );
                        return self.wip.gep(.inbounds, struct_llvm_ty, struct_ptr, &.{llvm_index}, "");
                    }
                },
            },
            .Union => {
                const layout = struct_ty.unionGetLayout(mod);
                if (layout.payload_size == 0 or struct_ty.containerLayout(mod) == .Packed) return struct_ptr;
                const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
                const union_llvm_ty = try o.lowerType(struct_ty);
                return self.wip.gepStruct(union_llvm_ty, struct_ptr, payload_index, "");
            },
            else => unreachable,
        }
    }

    /// Load a value and, if needed, mask out padding bits for non byte-sized integer values.
    fn loadTruncate(
        fg: *FuncGen,
        access_kind: Builder.MemoryAccessKind,
        payload_ty: Type,
        payload_ptr: Builder.Value,
        payload_alignment: Builder.Alignment,
    ) !Builder.Value {
        // from https://llvm.org/docs/LangRef.html#load-instruction :
        // "When loading a value of a type like i20 with a size that is not an integral number of bytes, the result is undefined if the value was not originally written using a store of the same type. "
        // => so load the byte aligned value and trunc the unwanted bits.

        const o = fg.dg.object;
        const mod = o.module;
        const payload_llvm_ty = try o.lowerType(payload_ty);
        const abi_size = payload_ty.abiSize(mod);

        // llvm bug workarounds:
        const workaround_explicit_mask = o.target.cpu.arch == .powerpc and abi_size >= 4;
        const workaround_disable_truncate = o.target.cpu.arch == .wasm32 and abi_size >= 4;

        if (workaround_disable_truncate) {
            // see https://github.com/llvm/llvm-project/issues/64222
            // disable the truncation codepath for larger that 32bits value - with this heuristic, the backend passes the test suite.
            return try fg.wip.load(access_kind, payload_llvm_ty, payload_ptr, payload_alignment, "");
        }

        const load_llvm_ty = if (payload_ty.isAbiInt(mod))
            try o.builder.intType(@intCast(abi_size * 8))
        else
            payload_llvm_ty;
        const loaded = try fg.wip.load(access_kind, load_llvm_ty, payload_ptr, payload_alignment, "");
        const shifted = if (payload_llvm_ty != load_llvm_ty and o.target.cpu.arch.endian() == .big)
            try fg.wip.bin(.lshr, loaded, try o.builder.intValue(
                load_llvm_ty,
                (payload_ty.abiSize(mod) - (std.math.divCeil(u64, payload_ty.bitSize(mod), 8) catch unreachable)) * 8,
            ), "")
        else
            loaded;

        const anded = if (workaround_explicit_mask and payload_llvm_ty != load_llvm_ty) blk: {
            // this is rendundant with llvm.trunc. But without it, llvm17 emits invalid code for powerpc.
            var mask_val = try o.builder.intConst(payload_llvm_ty, -1);
            mask_val = try o.builder.castConst(.zext, mask_val, load_llvm_ty);
            break :blk try fg.wip.bin(.@"and", shifted, mask_val.toValue(), "");
        } else shifted;

        return fg.wip.conv(.unneeded, anded, payload_llvm_ty, "");
    }

    /// Load a by-ref type by constructing a new alloca and performing a memcpy.
    fn loadByRef(
        fg: *FuncGen,
        ptr: Builder.Value,
        pointee_type: Type,
        ptr_alignment: Builder.Alignment,
        access_kind: Builder.MemoryAccessKind,
    ) !Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        //const pointee_llvm_ty = try o.lowerType(pointee_type);
        const result_align = InternPool.Alignment.fromLlvm(ptr_alignment).max(pointee_type.abiAlignment(mod)).toLlvm();
        const result_ptr = try fg.buildAllocaWorkaround(pointee_type, result_align);
        const size_bytes = pointee_type.abiSize(mod);
        _ = try fg.wip.callMemCpy(
            result_ptr,
            result_align,
            ptr,
            ptr_alignment,
            try o.builder.intValue(try o.lowerType(Type.usize), size_bytes),
            access_kind,
        );
        return result_ptr;
    }

    /// This function always performs a copy. For isByRef=true types, it creates a new
    /// alloca and copies the value into it, then returns the alloca instruction.
    /// For isByRef=false types, it creates a load instruction and returns it.
    fn load(self: *FuncGen, ptr: Builder.Value, ptr_ty: Type) !Builder.Value {
        const o = self.dg.object;
        const mod = o.module;
        const info = ptr_ty.ptrInfo(mod);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(mod)) return .none;

        const ptr_alignment = (if (info.flags.alignment != .none)
            @as(InternPool.Alignment, info.flags.alignment)
        else
            elem_ty.abiAlignment(mod)).toLlvm();

        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;

        assert(info.flags.vector_index != .runtime);
        if (info.flags.vector_index != .none) {
            const index_u32 = try o.builder.intValue(.i32, info.flags.vector_index);
            const vec_elem_ty = try o.lowerType(elem_ty);
            const vec_ty = try o.builder.vectorType(.normal, info.packed_offset.host_size, vec_elem_ty);

            const loaded_vector = try self.wip.load(access_kind, vec_ty, ptr, ptr_alignment, "");
            return self.wip.extractElement(loaded_vector, index_u32, "");
        }

        if (info.packed_offset.host_size == 0) {
            if (isByRef(elem_ty, mod)) {
                return self.loadByRef(ptr, elem_ty, ptr_alignment, access_kind);
            }
            return self.loadTruncate(access_kind, elem_ty, ptr, ptr_alignment);
        }

        const containing_int_ty = try o.builder.intType(@intCast(info.packed_offset.host_size * 8));
        const containing_int =
            try self.wip.load(access_kind, containing_int_ty, ptr, ptr_alignment, "");

        const elem_bits = ptr_ty.childType(mod).bitSize(mod);
        const shift_amt = try o.builder.intValue(containing_int_ty, info.packed_offset.bit_offset);
        const shifted_value = try self.wip.bin(.lshr, containing_int, shift_amt, "");
        const elem_llvm_ty = try o.lowerType(elem_ty);

        if (isByRef(elem_ty, mod)) {
            const result_align = elem_ty.abiAlignment(mod).toLlvm();
            const result_ptr = try self.buildAllocaWorkaround(elem_ty, result_align);

            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            _ = try self.wip.store(.normal, truncated_int, result_ptr, result_align);
            return result_ptr;
        }

        if (elem_ty.zigTypeTag(mod) == .Float or elem_ty.zigTypeTag(mod) == .Vector) {
            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
        }

        if (elem_ty.isPtrAtRuntime(mod)) {
            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
        }

        return self.wip.cast(.trunc, shifted_value, elem_llvm_ty, "");
    }

    fn store(
        self: *FuncGen,
        ptr: Builder.Value,
        ptr_ty: Type,
        elem: Builder.Value,
        ordering: Builder.AtomicOrdering,
    ) !void {
        const o = self.dg.object;
        const mod = o.module;
        const info = ptr_ty.ptrInfo(mod);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            return;
        }
        const ptr_alignment = ptr_ty.ptrAlignment(mod).toLlvm();
        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;

        assert(info.flags.vector_index != .runtime);
        if (info.flags.vector_index != .none) {
            const index_u32 = try o.builder.intValue(.i32, info.flags.vector_index);
            const vec_elem_ty = try o.lowerType(elem_ty);
            const vec_ty = try o.builder.vectorType(.normal, info.packed_offset.host_size, vec_elem_ty);

            const loaded_vector = try self.wip.load(access_kind, vec_ty, ptr, ptr_alignment, "");

            const modified_vector = try self.wip.insertElement(loaded_vector, elem, index_u32, "");

            assert(ordering == .none);
            _ = try self.wip.store(access_kind, modified_vector, ptr, ptr_alignment);
            return;
        }

        if (info.packed_offset.host_size != 0) {
            const containing_int_ty = try o.builder.intType(@intCast(info.packed_offset.host_size * 8));
            assert(ordering == .none);
            const containing_int =
                try self.wip.load(access_kind, containing_int_ty, ptr, ptr_alignment, "");
            const elem_bits = ptr_ty.childType(mod).bitSize(mod);
            const shift_amt = try o.builder.intConst(containing_int_ty, info.packed_offset.bit_offset);
            // Convert to equally-sized integer type in order to perform the bit
            // operations on the value to store
            const value_bits_type = try o.builder.intType(@intCast(elem_bits));
            const value_bits = if (elem_ty.isPtrAtRuntime(mod))
                try self.wip.cast(.ptrtoint, elem, value_bits_type, "")
            else
                try self.wip.cast(.bitcast, elem, value_bits_type, "");

            var mask_val = try o.builder.intConst(value_bits_type, -1);
            mask_val = try o.builder.castConst(.zext, mask_val, containing_int_ty);
            mask_val = try o.builder.binConst(.shl, mask_val, shift_amt);
            mask_val =
                try o.builder.binConst(.xor, mask_val, try o.builder.intConst(containing_int_ty, -1));

            const anded_containing_int =
                try self.wip.bin(.@"and", containing_int, mask_val.toValue(), "");
            const extended_value = try self.wip.cast(.zext, value_bits, containing_int_ty, "");
            const shifted_value = try self.wip.bin(.shl, extended_value, shift_amt.toValue(), "");
            const ored_value = try self.wip.bin(.@"or", shifted_value, anded_containing_int, "");

            assert(ordering == .none);
            _ = try self.wip.store(access_kind, ored_value, ptr, ptr_alignment);
            return;
        }
        if (!isByRef(elem_ty, mod)) {
            _ = try self.wip.storeAtomic(
                access_kind,
                elem,
                ptr,
                self.sync_scope,
                ordering,
                ptr_alignment,
            );
            return;
        }
        assert(ordering == .none);
        _ = try self.wip.callMemCpy(
            ptr,
            ptr_alignment,
            elem,
            elem_ty.abiAlignment(mod).toLlvm(),
            try o.builder.intValue(try o.lowerType(Type.usize), elem_ty.abiSize(mod)),
            access_kind,
        );
    }

    fn valgrindMarkUndef(fg: *FuncGen, ptr: Builder.Value, len: Builder.Value) Allocator.Error!void {
        const VG_USERREQ__MAKE_MEM_UNDEFINED = 1296236545;
        const o = fg.dg.object;
        const usize_ty = try o.lowerType(Type.usize);
        const zero = try o.builder.intValue(usize_ty, 0);
        const req = try o.builder.intValue(usize_ty, VG_USERREQ__MAKE_MEM_UNDEFINED);
        const ptr_as_usize = try fg.wip.cast(.ptrtoint, ptr, usize_ty, "");
        _ = try valgrindClientRequest(fg, zero, req, ptr_as_usize, len, zero, zero, zero);
    }

    fn valgrindClientRequest(
        fg: *FuncGen,
        default_value: Builder.Value,
        request: Builder.Value,
        a1: Builder.Value,
        a2: Builder.Value,
        a3: Builder.Value,
        a4: Builder.Value,
        a5: Builder.Value,
    ) Allocator.Error!Builder.Value {
        const o = fg.dg.object;
        const mod = o.module;
        const target = mod.getTarget();
        if (!target_util.hasValgrindSupport(target)) return default_value;

        const llvm_usize = try o.lowerType(Type.usize);
        const usize_alignment = Type.usize.abiAlignment(mod).toLlvm();

        const array_llvm_ty = try o.builder.arrayType(6, llvm_usize);
        const array_ptr = if (fg.valgrind_client_request_array == .none) a: {
            const array_ptr = try fg.buildAlloca(array_llvm_ty, usize_alignment);
            fg.valgrind_client_request_array = array_ptr;
            break :a array_ptr;
        } else fg.valgrind_client_request_array;
        const array_elements = [_]Builder.Value{ request, a1, a2, a3, a4, a5 };
        const zero = try o.builder.intValue(llvm_usize, 0);
        for (array_elements, 0..) |elem, i| {
            const elem_ptr = try fg.wip.gep(.inbounds, array_llvm_ty, array_ptr, &.{
                zero, try o.builder.intValue(llvm_usize, i),
            }, "");
            _ = try fg.wip.store(.normal, elem, elem_ptr, usize_alignment);
        }

        const arch_specific: struct {
            template: [:0]const u8,
            constraints: [:0]const u8,
        } = switch (target.cpu.arch) {
            .x86 => .{
                .template =
                \\roll $$3,  %edi ; roll $$13, %edi
                \\roll $$61, %edi ; roll $$51, %edi
                \\xchgl %ebx,%ebx
                ,
                .constraints = "={edx},{eax},0,~{cc},~{memory}",
            },
            .x86_64 => .{
                .template =
                \\rolq $$3,  %rdi ; rolq $$13, %rdi
                \\rolq $$61, %rdi ; rolq $$51, %rdi
                \\xchgq %rbx,%rbx
                ,
                .constraints = "={rdx},{rax},0,~{cc},~{memory}",
            },
            .aarch64, .aarch64_32, .aarch64_be => .{
                .template =
                \\ror x12, x12, #3  ;  ror x12, x12, #13
                \\ror x12, x12, #51 ;  ror x12, x12, #61
                \\orr x10, x10, x10
                ,
                .constraints = "={x3},{x4},0,~{cc},~{memory}",
            },
            else => unreachable,
        };

        return fg.wip.callAsm(
            .none,
            try o.builder.fnType(llvm_usize, &.{ llvm_usize, llvm_usize }, .normal),
            .{ .sideeffect = true },
            try o.builder.string(arch_specific.template),
            try o.builder.string(arch_specific.constraints),
            &.{ try fg.wip.cast(.ptrtoint, array_ptr, llvm_usize, ""), default_value },
            "",
        );
    }

    fn typeOf(fg: *FuncGen, inst: Air.Inst.Ref) Type {
        const o = fg.dg.object;
        const mod = o.module;
        return fg.air.typeOf(inst, &mod.intern_pool);
    }

    fn typeOfIndex(fg: *FuncGen, inst: Air.Inst.Index) Type {
        const o = fg.dg.object;
        const mod = o.module;
        return fg.air.typeOfIndex(inst, &mod.intern_pool);
    }
};

fn toLlvmAtomicOrdering(atomic_order: std.builtin.AtomicOrder) Builder.AtomicOrdering {
    return switch (atomic_order) {
        .Unordered => .unordered,
        .Monotonic => .monotonic,
        .Acquire => .acquire,
        .Release => .release,
        .AcqRel => .acq_rel,
        .SeqCst => .seq_cst,
    };
}

fn toLlvmAtomicRmwBinOp(
    op: std.builtin.AtomicRmwOp,
    is_signed: bool,
    is_float: bool,
) Builder.Function.Instruction.AtomicRmw.Operation {
    return switch (op) {
        .Xchg => .xchg,
        .Add => if (is_float) .fadd else return .add,
        .Sub => if (is_float) .fsub else return .sub,
        .And => .@"and",
        .Nand => .nand,
        .Or => .@"or",
        .Xor => .xor,
        .Max => if (is_float) .fmax else if (is_signed) .max else return .umax,
        .Min => if (is_float) .fmin else if (is_signed) .min else return .umin,
    };
}

fn toLlvmCallConv(cc: std.builtin.CallingConvention, target: std.Target) Builder.CallConv {
    return switch (cc) {
        .Unspecified, .Inline, .Async => .fastcc,
        .C, .Naked => .ccc,
        .Stdcall => .x86_stdcallcc,
        .Fastcall => .x86_fastcallcc,
        .Vectorcall => return switch (target.cpu.arch) {
            .x86, .x86_64 => .x86_vectorcallcc,
            .aarch64, .aarch64_be, .aarch64_32 => .aarch64_vector_pcs,
            else => unreachable,
        },
        .Thiscall => .x86_thiscallcc,
        .APCS => .arm_apcscc,
        .AAPCS => .arm_aapcscc,
        .AAPCSVFP => .arm_aapcs_vfpcc,
        .Interrupt => return switch (target.cpu.arch) {
            .x86, .x86_64 => .x86_intrcc,
            .avr => .avr_intrcc,
            .msp430 => .msp430_intrcc,
            else => unreachable,
        },
        .Signal => .avr_signalcc,
        .SysV => .x86_64_sysvcc,
        .Win64 => .win64cc,
        .Kernel => return switch (target.cpu.arch) {
            .nvptx, .nvptx64 => .ptx_kernel,
            .amdgcn => .amdgpu_kernel,
            else => unreachable,
        },
    };
}

/// Convert a zig-address space to an llvm address space.
fn toLlvmAddressSpace(address_space: std.builtin.AddressSpace, target: std.Target) Builder.AddrSpace {
    for (llvmAddrSpaceInfo(target)) |info| if (info.zig == address_space) return info.llvm;
    unreachable;
}

const AddrSpaceInfo = struct {
    zig: ?std.builtin.AddressSpace,
    llvm: Builder.AddrSpace,
    non_integral: bool = false,
    size: ?u16 = null,
    abi: ?u16 = null,
    pref: ?u16 = null,
    idx: ?u16 = null,
    force_in_data_layout: bool = false,
};
fn llvmAddrSpaceInfo(target: std.Target) []const AddrSpaceInfo {
    return switch (target.cpu.arch) {
        .x86, .x86_64 => &.{
            .{ .zig = .generic, .llvm = .default },
            .{ .zig = .gs, .llvm = Builder.AddrSpace.x86.gs },
            .{ .zig = .fs, .llvm = Builder.AddrSpace.x86.fs },
            .{ .zig = .ss, .llvm = Builder.AddrSpace.x86.ss },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr32_sptr, .size = 32, .abi = 32, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr32_uptr, .size = 32, .abi = 32, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr64, .size = 64, .abi = 64, .force_in_data_layout = true },
        },
        .nvptx, .nvptx64 => &.{
            .{ .zig = .generic, .llvm = .default },
            .{ .zig = .global, .llvm = Builder.AddrSpace.nvptx.global },
            .{ .zig = .constant, .llvm = Builder.AddrSpace.nvptx.constant },
            .{ .zig = .param, .llvm = Builder.AddrSpace.nvptx.param },
            .{ .zig = .shared, .llvm = Builder.AddrSpace.nvptx.shared },
            .{ .zig = .local, .llvm = Builder.AddrSpace.nvptx.local },
        },
        .amdgcn => &.{
            .{ .zig = .generic, .llvm = Builder.AddrSpace.amdgpu.flat, .force_in_data_layout = true },
            .{ .zig = .global, .llvm = Builder.AddrSpace.amdgpu.global, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.region, .size = 32, .abi = 32 },
            .{ .zig = .shared, .llvm = Builder.AddrSpace.amdgpu.local, .size = 32, .abi = 32 },
            .{ .zig = .constant, .llvm = Builder.AddrSpace.amdgpu.constant, .force_in_data_layout = true },
            .{ .zig = .local, .llvm = Builder.AddrSpace.amdgpu.private, .size = 32, .abi = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_32bit, .size = 32, .abi = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.buffer_fat_pointer, .non_integral = true, .size = 160, .abi = 256, .idx = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.buffer_resource, .non_integral = true, .size = 128, .abi = 128 },
        },
        .avr => &.{
            .{ .zig = .generic, .llvm = .default, .abi = 8 },
            .{ .zig = .flash, .llvm = Builder.AddrSpace.avr.program, .abi = 8 },
            .{ .zig = .flash1, .llvm = Builder.AddrSpace.avr.program1, .abi = 8 },
            .{ .zig = .flash2, .llvm = Builder.AddrSpace.avr.program2, .abi = 8 },
            .{ .zig = .flash3, .llvm = Builder.AddrSpace.avr.program3, .abi = 8 },
            .{ .zig = .flash4, .llvm = Builder.AddrSpace.avr.program4, .abi = 8 },
            .{ .zig = .flash5, .llvm = Builder.AddrSpace.avr.program5, .abi = 8 },
        },
        .wasm32, .wasm64 => &.{
            .{ .zig = .generic, .llvm = .default, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.variable, .non_integral = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.externref, .non_integral = true, .size = 8, .abi = 8 },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.funcref, .non_integral = true, .size = 8, .abi = 8 },
        },
        .m68k => &.{
            .{ .zig = .generic, .llvm = .default, .abi = 16, .pref = 32 },
        },
        else => &.{
            .{ .zig = .generic, .llvm = .default },
        },
    };
}

/// On some targets, local values that are in the generic address space must be generated into a
/// different address, space and then cast back to the generic address space.
/// For example, on GPUs local variable declarations must be generated into the local address space.
/// This function returns the address space local values should be generated into.
fn llvmAllocaAddressSpace(target: std.Target) Builder.AddrSpace {
    return switch (target.cpu.arch) {
        // On amdgcn, locals should be generated into the private address space.
        // To make Zig not impossible to use, these are then converted to addresses in the
        // generic address space and treates as regular pointers. This is the way that HIP also does it.
        .amdgcn => Builder.AddrSpace.amdgpu.private,
        else => .default,
    };
}

/// On some targets, global values that are in the generic address space must be generated into a
/// different address space, and then cast back to the generic address space.
fn llvmDefaultGlobalAddressSpace(target: std.Target) Builder.AddrSpace {
    return switch (target.cpu.arch) {
        // On amdgcn, globals must be explicitly allocated and uploaded so that the program can access
        // them.
        .amdgcn => Builder.AddrSpace.amdgpu.global,
        else => .default,
    };
}

/// Return the actual address space that a value should be stored in if its a global address space.
/// When a value is placed in the resulting address space, it needs to be cast back into wanted_address_space.
fn toLlvmGlobalAddressSpace(wanted_address_space: std.builtin.AddressSpace, target: std.Target) Builder.AddrSpace {
    return switch (wanted_address_space) {
        .generic => llvmDefaultGlobalAddressSpace(target),
        else => |as| toLlvmAddressSpace(as, target),
    };
}

fn firstParamSRet(fn_info: InternPool.Key.FuncType, mod: *Module) bool {
    const return_type = Type.fromInterned(fn_info.return_type);
    if (!return_type.hasRuntimeBitsIgnoreComptime(mod)) return false;

    const target = mod.getTarget();
    switch (fn_info.cc) {
        .Unspecified, .Inline => return isByRef(return_type, mod),
        .C => switch (target.cpu.arch) {
            .mips, .mipsel => return false,
            .x86_64 => switch (target.os.tag) {
                .windows => return x86_64_abi.classifyWindows(return_type, mod) == .memory,
                else => return firstParamSRetSystemV(return_type, mod),
            },
            .wasm32 => return wasm_c_abi.classifyType(return_type, mod)[0] == .indirect,
            .aarch64, .aarch64_be => return aarch64_c_abi.classifyType(return_type, mod) == .memory,
            .arm, .armeb => switch (arm_c_abi.classifyType(return_type, mod, .ret)) {
                .memory, .i64_array => return true,
                .i32_array => |size| return size != 1,
                .byval => return false,
            },
            .riscv32, .riscv64 => return riscv_c_abi.classifyType(return_type, mod) == .memory,
            else => return false, // TODO investigate C ABI for other architectures
        },
        .SysV => return firstParamSRetSystemV(return_type, mod),
        .Win64 => return x86_64_abi.classifyWindows(return_type, mod) == .memory,
        .Stdcall => return !isScalar(mod, return_type),
        else => return false,
    }
}

fn firstParamSRetSystemV(ty: Type, mod: *Module) bool {
    const class = x86_64_abi.classifySystemV(ty, mod, .ret);
    if (class[0] == .memory) return true;
    if (class[0] == .x87 and class[2] != .none) return true;
    return false;
}

/// In order to support the C calling convention, some return types need to be lowered
/// completely differently in the function prototype to honor the C ABI, and then
/// be effectively bitcasted to the actual return type.
fn lowerFnRetTy(o: *Object, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const mod = o.module;
    const return_type = Type.fromInterned(fn_info.return_type);
    if (!return_type.hasRuntimeBitsIgnoreComptime(mod)) {
        // If the return type is an error set or an error union, then we make this
        // anyerror return type instead, so that it can be coerced into a function
        // pointer type which has anyerror as the return type.
        return if (return_type.isError(mod)) try o.errorIntType() else .void;
    }
    const target = mod.getTarget();
    switch (fn_info.cc) {
        .Unspecified,
        .Inline,
        => return if (isByRef(return_type, mod)) .void else o.lowerType(return_type),
        .C => {
            switch (target.cpu.arch) {
                .mips, .mipsel => return o.lowerType(return_type),
                .x86_64 => switch (target.os.tag) {
                    .windows => return lowerWin64FnRetTy(o, fn_info),
                    else => return lowerSystemVFnRetTy(o, fn_info),
                },
                .wasm32 => {
                    if (isScalar(mod, return_type)) {
                        return o.lowerType(return_type);
                    }
                    const classes = wasm_c_abi.classifyType(return_type, mod);
                    if (classes[0] == .indirect or classes[0] == .none) {
                        return .void;
                    }

                    assert(classes[0] == .direct and classes[1] == .none);
                    const scalar_type = wasm_c_abi.scalarType(return_type, mod);
                    return o.builder.intType(@intCast(scalar_type.abiSize(mod) * 8));
                },
                .aarch64, .aarch64_be => {
                    switch (aarch64_c_abi.classifyType(return_type, mod)) {
                        .memory => return .void,
                        .float_array => return o.lowerType(return_type),
                        .byval => return o.lowerType(return_type),
                        .integer => return o.builder.intType(@intCast(return_type.bitSize(mod))),
                        .double_integer => return o.builder.arrayType(2, .i64),
                    }
                },
                .arm, .armeb => {
                    switch (arm_c_abi.classifyType(return_type, mod, .ret)) {
                        .memory, .i64_array => return .void,
                        .i32_array => |len| return if (len == 1) .i32 else .void,
                        .byval => return o.lowerType(return_type),
                    }
                },
                .riscv32, .riscv64 => {
                    switch (riscv_c_abi.classifyType(return_type, mod)) {
                        .memory => return .void,
                        .integer => {
                            return o.builder.intType(@intCast(return_type.bitSize(mod)));
                        },
                        .double_integer => {
                            return o.builder.structType(.normal, &.{ .i64, .i64 });
                        },
                        .byval => return o.lowerType(return_type),
                        .fields => {
                            var types_len: usize = 0;
                            var types: [8]Builder.Type = undefined;
                            for (0..return_type.structFieldCount(mod)) |field_index| {
                                const field_ty = return_type.structFieldType(field_index, mod);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                                types[types_len] = try o.lowerType(field_ty);
                                types_len += 1;
                            }
                            return o.builder.structType(.normal, types[0..types_len]);
                        },
                    }
                },
                // TODO investigate C ABI for other architectures
                else => return o.lowerType(return_type),
            }
        },
        .Win64 => return lowerWin64FnRetTy(o, fn_info),
        .SysV => return lowerSystemVFnRetTy(o, fn_info),
        .Stdcall => return if (isScalar(mod, return_type)) o.lowerType(return_type) else .void,
        else => return o.lowerType(return_type),
    }
}

fn lowerWin64FnRetTy(o: *Object, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const mod = o.module;
    const return_type = Type.fromInterned(fn_info.return_type);
    switch (x86_64_abi.classifyWindows(return_type, mod)) {
        .integer => {
            if (isScalar(mod, return_type)) {
                return o.lowerType(return_type);
            } else {
                return o.builder.intType(@intCast(return_type.abiSize(mod) * 8));
            }
        },
        .win_i128 => return o.builder.vectorType(.normal, 2, .i64),
        .memory => return .void,
        .sse => return o.lowerType(return_type),
        else => unreachable,
    }
}

fn lowerSystemVFnRetTy(o: *Object, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const mod = o.module;
    const ip = &mod.intern_pool;
    const return_type = Type.fromInterned(fn_info.return_type);
    if (isScalar(mod, return_type)) {
        return o.lowerType(return_type);
    }
    const classes = x86_64_abi.classifySystemV(return_type, mod, .ret);
    if (classes[0] == .memory) return .void;
    var types_index: u32 = 0;
    var types_buffer: [8]Builder.Type = undefined;
    for (classes) |class| {
        switch (class) {
            .integer => {
                types_buffer[types_index] = .i64;
                types_index += 1;
            },
            .sse, .sseup => {
                types_buffer[types_index] = .double;
                types_index += 1;
            },
            .float => {
                types_buffer[types_index] = .float;
                types_index += 1;
            },
            .float_combine => {
                types_buffer[types_index] = try o.builder.vectorType(.normal, 2, .float);
                types_index += 1;
            },
            .x87 => {
                if (types_index != 0 or classes[2] != .none) return .void;
                types_buffer[types_index] = .x86_fp80;
                types_index += 1;
            },
            .x87up => continue,
            .complex_x87 => {
                @panic("TODO");
            },
            .memory => unreachable, // handled above
            .win_i128 => unreachable, // windows only
            .none => break,
        }
    }
    const first_non_integer = std.mem.indexOfNone(x86_64_abi.Class, &classes, &.{.integer});
    if (first_non_integer == null or classes[first_non_integer.?] == .none) {
        assert(first_non_integer orelse classes.len == types_index);
        switch (ip.indexToKey(return_type.toIntern())) {
            .struct_type => |struct_type| {
                assert(struct_type.haveLayout(ip));
                const size: u64 = struct_type.size(ip).*;
                assert((std.math.divCeil(u64, size, 8) catch unreachable) == types_index);
                if (size % 8 > 0) {
                    types_buffer[types_index - 1] = try o.builder.intType(@intCast(size % 8 * 8));
                }
            },
            else => {},
        }
        if (types_index == 1) return types_buffer[0];
    }
    return o.builder.structType(.normal, types_buffer[0..types_index]);
}

const ParamTypeIterator = struct {
    object: *Object,
    fn_info: InternPool.Key.FuncType,
    zig_index: u32,
    llvm_index: u32,
    types_len: u32,
    types_buffer: [8]Builder.Type,
    byval_attr: bool,

    const Lowering = union(enum) {
        no_bits,
        byval,
        byref,
        byref_mut,
        abi_sized_int,
        multiple_llvm_types,
        slice,
        as_u16,
        float_array: u8,
        i32_array: u8,
        i64_array: u8,
    };

    pub fn next(it: *ParamTypeIterator) Allocator.Error!?Lowering {
        if (it.zig_index >= it.fn_info.param_types.len) return null;
        const mod = it.object.module;
        const ip = &mod.intern_pool;
        const ty = it.fn_info.param_types.get(ip)[it.zig_index];
        it.byval_attr = false;
        return nextInner(it, Type.fromInterned(ty));
    }

    /// `airCall` uses this instead of `next` so that it can take into account variadic functions.
    pub fn nextCall(it: *ParamTypeIterator, fg: *FuncGen, args: []const Air.Inst.Ref) Allocator.Error!?Lowering {
        const mod = it.object.module;
        const ip = &mod.intern_pool;
        if (it.zig_index >= it.fn_info.param_types.len) {
            if (it.zig_index >= args.len) {
                return null;
            } else {
                return nextInner(it, fg.typeOf(args[it.zig_index]));
            }
        } else {
            return nextInner(it, Type.fromInterned(it.fn_info.param_types.get(ip)[it.zig_index]));
        }
    }

    fn nextInner(it: *ParamTypeIterator, ty: Type) Allocator.Error!?Lowering {
        const mod = it.object.module;
        const target = mod.getTarget();

        if (!ty.hasRuntimeBitsIgnoreComptime(mod)) {
            it.zig_index += 1;
            return .no_bits;
        }
        switch (it.fn_info.cc) {
            .Unspecified, .Inline => {
                it.zig_index += 1;
                it.llvm_index += 1;
                if (ty.isSlice(mod) or
                    (ty.zigTypeTag(mod) == .Optional and ty.optionalChild(mod).isSlice(mod) and !ty.ptrAllowsZero(mod)))
                {
                    it.llvm_index += 1;
                    return .slice;
                } else if (isByRef(ty, mod)) {
                    return .byref;
                } else {
                    return .byval;
                }
            },
            .Async => {
                @panic("TODO implement async function lowering in the LLVM backend");
            },
            .C => {
                switch (target.cpu.arch) {
                    .mips, .mipsel => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        return .byval;
                    },
                    .x86_64 => switch (target.os.tag) {
                        .windows => return it.nextWin64(ty),
                        else => return it.nextSystemV(ty),
                    },
                    .wasm32 => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        if (isScalar(mod, ty)) {
                            return .byval;
                        }
                        const classes = wasm_c_abi.classifyType(ty, mod);
                        if (classes[0] == .indirect) {
                            return .byref;
                        }
                        return .abi_sized_int;
                    },
                    .aarch64, .aarch64_be => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        switch (aarch64_c_abi.classifyType(ty, mod)) {
                            .memory => return .byref_mut,
                            .float_array => |len| return Lowering{ .float_array = len },
                            .byval => return .byval,
                            .integer => {
                                it.types_len = 1;
                                it.types_buffer[0] = .i64;
                                return .multiple_llvm_types;
                            },
                            .double_integer => return Lowering{ .i64_array = 2 },
                        }
                    },
                    .arm, .armeb => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        switch (arm_c_abi.classifyType(ty, mod, .arg)) {
                            .memory => {
                                it.byval_attr = true;
                                return .byref;
                            },
                            .byval => return .byval,
                            .i32_array => |size| return Lowering{ .i32_array = size },
                            .i64_array => |size| return Lowering{ .i64_array = size },
                        }
                    },
                    .riscv32, .riscv64 => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        if (ty.toIntern() == .f16_type and
                            !std.Target.riscv.featureSetHas(target.cpu.features, .d)) return .as_u16;
                        switch (riscv_c_abi.classifyType(ty, mod)) {
                            .memory => return .byref_mut,
                            .byval => return .byval,
                            .integer => return .abi_sized_int,
                            .double_integer => return Lowering{ .i64_array = 2 },
                            .fields => {
                                it.types_len = 0;
                                for (0..ty.structFieldCount(mod)) |field_index| {
                                    const field_ty = ty.structFieldType(field_index, mod);
                                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                                    it.types_buffer[it.types_len] = try it.object.lowerType(field_ty);
                                    it.types_len += 1;
                                }
                                it.llvm_index += it.types_len - 1;
                                return .multiple_llvm_types;
                            },
                        }
                    },
                    // TODO investigate C ABI for other architectures
                    else => {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        return .byval;
                    },
                }
            },
            .Win64 => return it.nextWin64(ty),
            .SysV => return it.nextSystemV(ty),
            .Stdcall => {
                it.zig_index += 1;
                it.llvm_index += 1;

                if (isScalar(mod, ty)) {
                    return .byval;
                } else {
                    it.byval_attr = true;
                    return .byref;
                }
            },
            else => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byval;
            },
        }
    }

    fn nextWin64(it: *ParamTypeIterator, ty: Type) ?Lowering {
        const mod = it.object.module;
        switch (x86_64_abi.classifyWindows(ty, mod)) {
            .integer => {
                if (isScalar(mod, ty)) {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    return .byval;
                } else {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    return .abi_sized_int;
                }
            },
            .win_i128 => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byref;
            },
            .memory => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byref_mut;
            },
            .sse => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byval;
            },
            else => unreachable,
        }
    }

    fn nextSystemV(it: *ParamTypeIterator, ty: Type) Allocator.Error!?Lowering {
        const mod = it.object.module;
        const ip = &mod.intern_pool;
        const classes = x86_64_abi.classifySystemV(ty, mod, .arg);
        if (classes[0] == .memory) {
            it.zig_index += 1;
            it.llvm_index += 1;
            it.byval_attr = true;
            return .byref;
        }
        if (isScalar(mod, ty)) {
            it.zig_index += 1;
            it.llvm_index += 1;
            return .byval;
        }
        var types_index: u32 = 0;
        var types_buffer: [8]Builder.Type = undefined;
        for (classes) |class| {
            switch (class) {
                .integer => {
                    types_buffer[types_index] = .i64;
                    types_index += 1;
                },
                .sse, .sseup => {
                    types_buffer[types_index] = .double;
                    types_index += 1;
                },
                .float => {
                    types_buffer[types_index] = .float;
                    types_index += 1;
                },
                .float_combine => {
                    types_buffer[types_index] = try it.object.builder.vectorType(.normal, 2, .float);
                    types_index += 1;
                },
                .x87 => {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    it.byval_attr = true;
                    return .byref;
                },
                .x87up => unreachable,
                .complex_x87 => {
                    @panic("TODO");
                },
                .memory => unreachable, // handled above
                .win_i128 => unreachable, // windows only
                .none => break,
            }
        }
        const first_non_integer = std.mem.indexOfNone(x86_64_abi.Class, &classes, &.{.integer});
        if (first_non_integer == null or classes[first_non_integer.?] == .none) {
            assert(first_non_integer orelse classes.len == types_index);
            if (types_index == 1) {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .abi_sized_int;
            }
            switch (ip.indexToKey(ty.toIntern())) {
                .struct_type => |struct_type| {
                    assert(struct_type.haveLayout(ip));
                    const size: u64 = struct_type.size(ip).*;
                    assert((std.math.divCeil(u64, size, 8) catch unreachable) == types_index);
                    if (size % 8 > 0) {
                        types_buffer[types_index - 1] =
                            try it.object.builder.intType(@intCast(size % 8 * 8));
                    }
                },
                else => {},
            }
        }
        it.types_len = types_index;
        it.types_buffer = types_buffer;
        it.llvm_index += types_index;
        it.zig_index += 1;
        return .multiple_llvm_types;
    }
};

fn iterateParamTypes(object: *Object, fn_info: InternPool.Key.FuncType) ParamTypeIterator {
    return .{
        .object = object,
        .fn_info = fn_info,
        .zig_index = 0,
        .llvm_index = 0,
        .types_len = 0,
        .types_buffer = undefined,
        .byval_attr = false,
    };
}

fn ccAbiPromoteInt(
    cc: std.builtin.CallingConvention,
    mod: *Module,
    ty: Type,
) ?std.builtin.Signedness {
    const target = mod.getTarget();
    switch (cc) {
        .Unspecified, .Inline, .Async => return null,
        else => {},
    }
    const int_info = switch (ty.zigTypeTag(mod)) {
        .Bool => Type.u1.intInfo(mod),
        .Int, .Enum, .ErrorSet => ty.intInfo(mod),
        else => return null,
    };
    if (int_info.bits <= 16) return int_info.signedness;
    switch (target.cpu.arch) {
        .riscv64 => {
            if (int_info.bits == 32) {
                // LLVM always signextends 32 bit ints, unsure if bug.
                return .signed;
            }
            if (int_info.bits < 64) {
                return int_info.signedness;
            }
        },
        .sparc64,
        .powerpc64,
        .powerpc64le,
        => {
            if (int_info.bits < 64) {
                return int_info.signedness;
            }
        },
        else => {},
    }
    return null;
}

/// This is the one source of truth for whether a type is passed around as an LLVM pointer,
/// or as an LLVM value.
fn isByRef(ty: Type, mod: *Module) bool {
    // For tuples and structs, if there are more than this many non-void
    // fields, then we make it byref, otherwise byval.
    const max_fields_byval = 0;
    const ip = &mod.intern_pool;

    switch (ty.zigTypeTag(mod)) {
        .Type,
        .ComptimeInt,
        .ComptimeFloat,
        .EnumLiteral,
        .Undefined,
        .Null,
        .Opaque,
        => unreachable,

        .NoReturn,
        .Void,
        .Bool,
        .Int,
        .Float,
        .Pointer,
        .ErrorSet,
        .Fn,
        .Enum,
        .Vector,
        .AnyFrame,
        => return false,

        .Array, .Frame => return ty.hasRuntimeBits(mod),
        .Struct => {
            const struct_type = switch (ip.indexToKey(ty.toIntern())) {
                .anon_struct_type => |tuple| {
                    var count: usize = 0;
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                        if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

                        count += 1;
                        if (count > max_fields_byval) return true;
                        if (isByRef(Type.fromInterned(field_ty), mod)) return true;
                    }
                    return false;
                },
                .struct_type => |s| s,
                else => unreachable,
            };

            // Packed structs are represented to LLVM as integers.
            if (struct_type.layout == .Packed) return false;

            const field_types = struct_type.field_types.get(ip);
            var it = struct_type.iterateRuntimeOrder(ip);
            var count: usize = 0;
            while (it.next()) |field_index| {
                count += 1;
                if (count > max_fields_byval) return true;
                const field_ty = Type.fromInterned(field_types[field_index]);
                if (isByRef(field_ty, mod)) return true;
            }
            return false;
        },
        .Union => switch (ty.containerLayout(mod)) {
            .Packed => return false,
            else => return ty.hasRuntimeBits(mod),
        },
        .ErrorUnion => {
            const payload_ty = ty.errorUnionPayload(mod);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                return false;
            }
            return true;
        },
        .Optional => {
            const payload_ty = ty.optionalChild(mod);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                return false;
            }
            if (ty.optionalReprIsPayload(mod)) {
                return false;
            }
            return true;
        },
    }
}

fn isScalar(mod: *Module, ty: Type) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Void,
        .Bool,
        .NoReturn,
        .Int,
        .Float,
        .Pointer,
        .Optional,
        .ErrorSet,
        .Enum,
        .AnyFrame,
        .Vector,
        => true,

        .Struct => ty.containerLayout(mod) == .Packed,
        .Union => ty.containerLayout(mod) == .Packed,
        else => false,
    };
}

/// This function returns true if we expect LLVM to lower x86_fp80 correctly
/// and false if we expect LLVM to crash if it counters an x86_fp80 type.
fn backendSupportsF80(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .x86_64, .x86 => !std.Target.x86.featureSetHas(target.cpu.features, .soft_float),
        else => false,
    };
}

/// This function returns true if we expect LLVM to lower f16 correctly
/// and false if we expect LLVM to crash if it counters an f16 type or
/// if it produces miscompilations.
fn backendSupportsF16(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .wasm32,
        .wasm64,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        => false,
        .aarch64 => std.Target.aarch64.featureSetHas(target.cpu.features, .fp_armv8),
        else => true,
    };
}

/// This function returns true if we expect LLVM to lower f128 correctly,
/// and false if we expect LLVm to crash if it encounters and f128 type
/// or if it produces miscompilations.
fn backendSupportsF128(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .amdgcn => false,
        .aarch64 => std.Target.aarch64.featureSetHas(target.cpu.features, .fp_armv8),
        else => true,
    };
}

/// LLVM does not support all relevant intrinsics for all targets, so we
/// may need to manually generate a libc call
fn intrinsicsAllowed(scalar_ty: Type, target: std.Target) bool {
    return switch (scalar_ty.toIntern()) {
        .f16_type => backendSupportsF16(target),
        .f80_type => (target.c_type_bit_size(.longdouble) == 80) and backendSupportsF80(target),
        .f128_type => (target.c_type_bit_size(.longdouble) == 128) and backendSupportsF128(target),
        else => true,
    };
}

/// We need to insert extra padding if LLVM's isn't enough.
/// However we don't want to ever call LLVMABIAlignmentOfType or
/// LLVMABISizeOfType because these functions will trip assertions
/// when using them for self-referential types. So our strategy is
/// to use non-packed llvm structs but to emit all padding explicitly.
/// We can do this because for all types, Zig ABI alignment >= LLVM ABI
/// alignment.
const struct_layout_version = 2;

// TODO: Restore the non_null field to i1 once
//       https://github.com/llvm/llvm-project/issues/56585/ is fixed
const optional_layout_version = 3;

/// We use the least significant bit of the pointer address to tell us
/// whether the type is fully resolved. Types that are only fwd declared
/// have the LSB flipped to a 1.
const AnnotatedDITypePtr = enum(usize) {
    _,

    fn initFwd(di_type: *llvm.DIType) AnnotatedDITypePtr {
        const addr = @intFromPtr(di_type);
        assert(@as(u1, @truncate(addr)) == 0);
        return @enumFromInt(addr | 1);
    }

    fn initFull(di_type: *llvm.DIType) AnnotatedDITypePtr {
        const addr = @intFromPtr(di_type);
        return @enumFromInt(addr);
    }

    fn init(di_type: *llvm.DIType, resolve: Object.DebugResolveStatus) AnnotatedDITypePtr {
        const addr = @intFromPtr(di_type);
        const bit = @intFromBool(resolve == .fwd);
        return @enumFromInt(addr | bit);
    }

    fn toDIType(self: AnnotatedDITypePtr) *llvm.DIType {
        const fixed_addr = @intFromEnum(self) & ~@as(usize, 1);
        return @ptrFromInt(fixed_addr);
    }

    fn isFwdOnly(self: AnnotatedDITypePtr) bool {
        return @as(u1, @truncate(@intFromEnum(self))) != 0;
    }
};

const lt_errors_fn_name = "__zig_lt_errors_len";

/// Without this workaround, LLVM crashes with "unknown codeview register H1"
/// https://github.com/llvm/llvm-project/issues/56484
fn needDbgVarWorkaround(o: *Object) bool {
    const target = o.module.getTarget();
    if (target.os.tag == .windows and target.cpu.arch == .aarch64) {
        return true;
    }
    return false;
}

fn compilerRtIntBits(bits: u16) u16 {
    inline for (.{ 32, 64, 128 }) |b| {
        if (bits <= b) {
            return b;
        }
    }
    return bits;
}

fn buildAllocaInner(
    wip: *Builder.WipFunction,
    di_scope_non_null: bool,
    llvm_ty: Builder.Type,
    alignment: Builder.Alignment,
    target: std.Target,
) Allocator.Error!Builder.Value {
    const address_space = llvmAllocaAddressSpace(target);

    const alloca = blk: {
        const prev_cursor = wip.cursor;
        const prev_debug_location = if (wip.builder.useLibLlvm())
            wip.llvm.builder.getCurrentDebugLocation2()
        else
            undefined;
        defer {
            wip.cursor = prev_cursor;
            if (wip.cursor.block == .entry) wip.cursor.instruction += 1;
            if (wip.builder.useLibLlvm() and di_scope_non_null)
                wip.llvm.builder.setCurrentDebugLocation2(prev_debug_location);
        }

        wip.cursor = .{ .block = .entry };
        if (wip.builder.useLibLlvm()) wip.llvm.builder.clearCurrentDebugLocation();
        break :blk try wip.alloca(.normal, llvm_ty, .none, alignment, address_space, "");
    };

    // The pointer returned from this function should have the generic address space,
    // if this isn't the case then cast it to the generic address space.
    return wip.conv(.unneeded, alloca, .ptr, "");
}

fn errUnionPayloadOffset(payload_ty: Type, mod: *Module) !u1 {
    const err_int_ty = try mod.errorIntType();
    return @intFromBool(err_int_ty.abiAlignment(mod).compare(.gt, payload_ty.abiAlignment(mod)));
}

fn errUnionErrorOffset(payload_ty: Type, mod: *Module) !u1 {
    const err_int_ty = try mod.errorIntType();
    return @intFromBool(err_int_ty.abiAlignment(mod).compare(.lte, payload_ty.abiAlignment(mod)));
}

/// Returns true for asm constraint (e.g. "=*m", "=r") if it accepts a memory location
///
/// See also TargetInfo::validateOutputConstraint, AArch64TargetInfo::validateAsmConstraint, etc. in Clang
fn constraintAllowsMemory(constraint: []const u8) bool {
    // TODO: This implementation is woefully incomplete.
    for (constraint) |byte| {
        switch (byte) {
            '=', '*', ',', '&' => {},
            'm', 'o', 'X', 'g' => return true,
            else => {},
        }
    } else return false;
}

/// Returns true for asm constraint (e.g. "=*m", "=r") if it accepts a register
///
/// See also TargetInfo::validateOutputConstraint, AArch64TargetInfo::validateAsmConstraint, etc. in Clang
fn constraintAllowsRegister(constraint: []const u8) bool {
    // TODO: This implementation is woefully incomplete.
    for (constraint) |byte| {
        switch (byte) {
            '=', '*', ',', '&' => {},
            'm', 'o' => {},
            else => return true,
        }
    } else return false;
}
