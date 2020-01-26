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
        uefi,
        other,
    };

    pub const aarch64 = @import("target/aarch64.zig");
    pub const amdgpu = @import("target/amdgpu.zig");
    pub const arm = @import("target/arm.zig");
    pub const avr = @import("target/avr.zig");
    pub const bpf = @import("target/bpf.zig");
    pub const hexagon = @import("target/hexagon.zig");
    pub const mips = @import("target/mips.zig");
    pub const msp430 = @import("target/msp430.zig");
    pub const nvptx = @import("target/nvptx.zig");
    pub const powerpc = @import("target/powerpc.zig");
    pub const riscv = @import("target/riscv.zig");
    pub const sparc = @import("target/sparc.zig");
    pub const systemz = @import("target/systemz.zig");
    pub const wasm = @import("target/wasm.zig");
    pub const x86 = @import("target/x86.zig");

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
            v8a,
            v8r,
            v8m_baseline,
            v8m_mainline,
            v8_1m_mainline,
            v7a,
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

            pub fn version(version: Arm32) comptime_int {
                return switch (version) {
                    .v8_5a, .v8_4a, .v8_3a, .v8_2a, .v8_1a, .v8a, .v8r, .v8m_baseline, .v8m_mainline, .v8_1m_mainline => 8,
                    .v7a, .v7em, .v7m, .v7s, .v7k, .v7ve => 7,
                    .v6, .v6m, .v6k, .v6t2 => 6,
                    .v5, .v5te => 5,
                    .v4t => 4,
                };
            }
        };
        pub const Arm64 = enum {
            v8_5a,
            v8_4a,
            v8_3a,
            v8_2a,
            v8_1a,
            v8a,
        };
        pub const Kalimba = enum {
            v5,
            v4,
            v3,
        };
        pub const Mips = enum {
            r6,
        };

        pub fn subArchName(arch: Arch) ?[]const u8 {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => |arm32| @tagName(arm32),
                .aarch64, .aarch64_be, .aarch64_32 => |arm64| @tagName(arm64),
                .kalimba => |kalimba| @tagName(kalimba),
                else => return null,
            };
        }

        pub fn subArchFeature(arch: Arch) ?Cpu.Feature.Set.Index {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => |arm32| switch (arm32) {
                    .v8_5a => @enumToInt(arm.Feature.armv8_5_a),
                    .v8_4a => @enumToInt(arm.Feature.armv8_4_a),
                    .v8_3a => @enumToInt(arm.Feature.armv8_3_a),
                    .v8_2a => @enumToInt(arm.Feature.armv8_2_a),
                    .v8_1a => @enumToInt(arm.Feature.armv8_1_a),
                    .v8a => @enumToInt(arm.Feature.armv8_a),
                    .v8r => @enumToInt(arm.Feature.armv8_r),
                    .v8m_baseline => @enumToInt(arm.Feature.armv8_m_base),
                    .v8m_mainline => @enumToInt(arm.Feature.armv8_m_main),
                    .v8_1m_mainline => @enumToInt(arm.Feature.armv8_1_m_main),
                    .v7a => @enumToInt(arm.Feature.armv7_a),
                    .v7em => @enumToInt(arm.Feature.armv7e_m),
                    .v7m => @enumToInt(arm.Feature.armv7_m),
                    .v7s => @enumToInt(arm.Feature.armv7s),
                    .v7k => @enumToInt(arm.Feature.armv7k),
                    .v7ve => @enumToInt(arm.Feature.armv7ve),
                    .v6 => @enumToInt(arm.Feature.armv6),
                    .v6m => @enumToInt(arm.Feature.armv6_m),
                    .v6k => @enumToInt(arm.Feature.armv6k),
                    .v6t2 => @enumToInt(arm.Feature.armv6t2),
                    .v5 => @enumToInt(arm.Feature.armv5t),
                    .v5te => @enumToInt(arm.Feature.armv5te),
                    .v4t => @enumToInt(arm.Feature.armv4t),
                },
                .aarch64, .aarch64_be, .aarch64_32 => |arm64| switch (arm64) {
                    .v8_5a => @enumToInt(aarch64.Feature.v8_5a),
                    .v8_4a => @enumToInt(aarch64.Feature.v8_4a),
                    .v8_3a => @enumToInt(aarch64.Feature.v8_3a),
                    .v8_2a => @enumToInt(aarch64.Feature.v8_2a),
                    .v8_1a => @enumToInt(aarch64.Feature.v8_1a),
                    .v8a => @enumToInt(aarch64.Feature.v8a),
                },
                else => return null,
            };
        }

        pub fn isARM(arch: Arch) bool {
            return switch (arch) {
                .arm, .armeb => true,
                else => false,
            };
        }

        pub fn isThumb(arch: Arch) bool {
            return switch (arch) {
                .thumb, .thumbeb => true,
                else => false,
            };
        }

        pub fn isWasm(arch: Arch) bool {
            return switch (arch) {
                .wasm32, .wasm64 => true,
                else => false,
            };
        }

        pub fn isMIPS(arch: Arch) bool {
            return switch (arch) {
                .mips, .mipsel, .mips64, .mips64el => true,
                else => false,
            };
        }

        pub fn parseCpu(arch: Arch, cpu_name: []const u8) !*const Cpu {
            for (arch.allCpus()) |cpu| {
                if (mem.eql(u8, cpu_name, cpu.name)) {
                    return cpu;
                }
            }
            return error.UnknownCpu;
        }

        /// Comma-separated list of features, with + or - in front of each feature. This
        /// form represents a deviation from baseline CPU, which is provided as a parameter.
        /// Extra commas are ignored.
        pub fn parseCpuFeatureSet(arch: Arch, cpu: *const Cpu, features_text: []const u8) !Cpu.Feature.Set {
            const all_features = arch.allFeaturesList();
            var set = cpu.features;
            var it = mem.tokenize(features_text, ",");
            while (it.next()) |item_text| {
                var feature_name: []const u8 = undefined;
                var op: enum {
                    add,
                    sub,
                } = undefined;
                if (mem.startsWith(u8, item_text, "+")) {
                    op = .add;
                    feature_name = item_text[1..];
                } else if (mem.startsWith(u8, item_text, "-")) {
                    op = .sub;
                    feature_name = item_text[1..];
                } else {
                    return error.InvalidCpuFeatures;
                }
                for (all_features) |feature, index_usize| {
                    const index = @intCast(Cpu.Feature.Set.Index, index_usize);
                    if (mem.eql(u8, feature_name, feature.name)) {
                        switch (op) {
                            .add => set.addFeature(index),
                            .sub => set.removeFeature(index),
                        }
                        break;
                    }
                } else {
                    return error.UnknownCpuFeature;
                }
            }
            return set;
        }

        pub fn toElfMachine(arch: Arch) std.elf.EM {
            return switch (arch) {
                .avr => ._AVR,
                .msp430 => ._MSP430,
                .arc => ._ARC,
                .arm => ._ARM,
                .armeb => ._ARM,
                .hexagon => ._HEXAGON,
                .le32 => ._NONE,
                .mips => ._MIPS,
                .mipsel => ._MIPS_RS3_LE,
                .powerpc => ._PPC,
                .r600 => ._NONE,
                .riscv32 => ._RISCV,
                .sparc => ._SPARC,
                .sparcel => ._SPARC,
                .tce => ._NONE,
                .tcele => ._NONE,
                .thumb => ._ARM,
                .thumbeb => ._ARM,
                .i386 => ._386,
                .xcore => ._XCORE,
                .nvptx => ._NONE,
                .amdil => ._NONE,
                .hsail => ._NONE,
                .spir => ._NONE,
                .kalimba => ._CSR_KALIMBA,
                .shave => ._NONE,
                .lanai => ._LANAI,
                .wasm32 => ._NONE,
                .renderscript32 => ._NONE,
                .aarch64_32 => ._AARCH64,
                .aarch64 => ._AARCH64,
                .aarch64_be => ._AARCH64,
                .mips64 => ._MIPS,
                .mips64el => ._MIPS_RS3_LE,
                .powerpc64 => ._PPC64,
                .powerpc64le => ._PPC64,
                .riscv64 => ._RISCV,
                .x86_64 => ._X86_64,
                .nvptx64 => ._NONE,
                .le64 => ._NONE,
                .amdil64 => ._NONE,
                .hsail64 => ._NONE,
                .spir64 => ._NONE,
                .wasm64 => ._NONE,
                .renderscript64 => ._NONE,
                .amdgcn => ._NONE,
                .bpfel => ._BPF,
                .bpfeb => ._BPF,
                .sparcv9 => ._SPARCV9,
                .s390x => ._S390,
            };
        }

        pub fn endian(arch: Arch) builtin.Endian {
            return switch (arch) {
                .avr,
                .arm,
                .aarch64_32,
                .aarch64,
                .amdgcn,
                .amdil,
                .amdil64,
                .bpfel,
                .hexagon,
                .hsail,
                .hsail64,
                .kalimba,
                .le32,
                .le64,
                .mipsel,
                .mips64el,
                .msp430,
                .nvptx,
                .nvptx64,
                .sparcel,
                .tcele,
                .powerpc64le,
                .r600,
                .riscv32,
                .riscv64,
                .i386,
                .x86_64,
                .wasm32,
                .wasm64,
                .xcore,
                .thumb,
                .spir,
                .spir64,
                .renderscript32,
                .renderscript64,
                .shave,
                => .Little,

                .arc,
                .armeb,
                .aarch64_be,
                .bpfeb,
                .mips,
                .mips64,
                .powerpc,
                .powerpc64,
                .thumbeb,
                .sparc,
                .sparcv9,
                .tce,
                .lanai,
                .s390x,
                => .Big,
            };
        }

        /// Returns a name that matches the lib/std/target/* directory name.
        pub fn genericName(arch: Arch) []const u8 {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => "arm",
                .aarch64, .aarch64_be, .aarch64_32 => "aarch64",
                .avr => "avr",
                .bpfel, .bpfeb => "bpf",
                .hexagon => "hexagon",
                .mips, .mipsel, .mips64, .mips64el => "mips",
                .msp430 => "msp430",
                .powerpc, .powerpc64, .powerpc64le => "powerpc",
                .amdgcn => "amdgpu",
                .riscv32, .riscv64 => "riscv",
                .sparc, .sparcv9, .sparcel => "sparc",
                .s390x => "systemz",
                .i386, .x86_64 => "x86",
                .nvptx, .nvptx64 => "nvptx",
                .wasm32, .wasm64 => "wasm",
                else => @tagName(arch),
            };
        }

        /// All CPU features Zig is aware of, sorted lexicographically by name.
        pub fn allFeaturesList(arch: Arch) []const Cpu.Feature {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.all_features,
                .aarch64, .aarch64_be, .aarch64_32 => &aarch64.all_features,
                .avr => &avr.all_features,
                .bpfel, .bpfeb => &bpf.all_features,
                .hexagon => &hexagon.all_features,
                .mips, .mipsel, .mips64, .mips64el => &mips.all_features,
                .msp430 => &msp430.all_features,
                .powerpc, .powerpc64, .powerpc64le => &powerpc.all_features,
                .amdgcn => &amdgpu.all_features,
                .riscv32, .riscv64 => &riscv.all_features,
                .sparc, .sparcv9, .sparcel => &sparc.all_features,
                .s390x => &systemz.all_features,
                .i386, .x86_64 => &x86.all_features,
                .nvptx, .nvptx64 => &nvptx.all_features,
                .wasm32, .wasm64 => &wasm.all_features,

                else => &[0]Cpu.Feature{},
            };
        }

        /// The "default" set of CPU features for cross-compiling. A conservative set
        /// of features that is expected to be supported on most available hardware.
        pub fn getBaselineCpuFeatures(arch: Arch) CpuFeatures {
            const S = struct {
                const generic_cpu = Cpu{
                    .name = "generic",
                    .llvm_name = null,
                    .features = Cpu.Feature.Set.empty,
                };
            };
            const cpu = switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.generic,
                .aarch64, .aarch64_be, .aarch64_32 => &aarch64.cpu.generic,
                .avr => &avr.cpu.avr1,
                .bpfel, .bpfeb => &bpf.cpu.generic,
                .hexagon => &hexagon.cpu.generic,
                .mips, .mipsel => &mips.cpu.mips32,
                .mips64, .mips64el => &mips.cpu.mips64,
                .msp430 => &msp430.cpu.generic,
                .powerpc, .powerpc64, .powerpc64le => &powerpc.cpu.generic,
                .amdgcn => &amdgpu.cpu.generic,
                .riscv32 => &riscv.cpu.baseline_rv32,
                .riscv64 => &riscv.cpu.baseline_rv64,
                .sparc, .sparcv9, .sparcel => &sparc.cpu.generic,
                .s390x => &systemz.cpu.generic,
                .i386 => &x86.cpu.pentium4,
                .x86_64 => &x86.cpu.x86_64,
                .nvptx, .nvptx64 => &nvptx.cpu.sm_20,
                .wasm32, .wasm64 => &wasm.cpu.generic,

                else => &S.generic_cpu,
            };
            return CpuFeatures.initFromCpu(arch, cpu);
        }

        /// All CPUs Zig is aware of, sorted lexicographically by name.
        pub fn allCpus(arch: Arch) []const *const Cpu {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => arm.all_cpus,
                .aarch64, .aarch64_be, .aarch64_32 => aarch64.all_cpus,
                .avr => avr.all_cpus,
                .bpfel, .bpfeb => bpf.all_cpus,
                .hexagon => hexagon.all_cpus,
                .mips, .mipsel, .mips64, .mips64el => mips.all_cpus,
                .msp430 => msp430.all_cpus,
                .powerpc, .powerpc64, .powerpc64le => powerpc.all_cpus,
                .amdgcn => amdgpu.all_cpus,
                .riscv32, .riscv64 => riscv.all_cpus,
                .sparc, .sparcv9, .sparcel => sparc.all_cpus,
                .s390x => systemz.all_cpus,
                .i386, .x86_64 => x86.all_cpus,
                .nvptx, .nvptx64 => nvptx.all_cpus,
                .wasm32, .wasm64 => wasm.all_cpus,

                else => &[0]*const Cpu{},
            };
        }
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

    pub const Cpu = struct {
        name: []const u8,
        llvm_name: ?[:0]const u8,
        features: Feature.Set,

        pub const Feature = struct {
            /// The bit index into `Set`. Has a default value of `undefined` because the canonical
            /// structures are populated via comptime logic.
            index: Set.Index = undefined,

            /// Has a default value of `undefined` because the canonical
            /// structures are populated via comptime logic.
            name: []const u8 = undefined,

            /// If this corresponds to an LLVM-recognized feature, this will be populated;
            /// otherwise null.
            llvm_name: ?[:0]const u8,

            /// Human-friendly UTF-8 text.
            description: []const u8,

            /// Sparse `Set` of features this depends on.
            dependencies: Set,

            /// A bit set of all the features.
            pub const Set = struct {
                ints: [usize_count]usize,

                pub const needed_bit_count = 174;
                pub const byte_count = (needed_bit_count + 7) / 8;
                pub const usize_count = (byte_count + (@sizeOf(usize) - 1)) / @sizeOf(usize);
                pub const Index = std.math.Log2Int(@IntType(false, usize_count * @bitSizeOf(usize)));
                pub const ShiftInt = std.math.Log2Int(usize);

                pub const empty = Set{ .ints = [1]usize{0} ** usize_count };
                pub fn empty_workaround() Set {
                    return Set{ .ints = [1]usize{0} ** usize_count };
                }

                pub fn isEnabled(set: Set, arch_feature_index: Index) bool {
                    const usize_index = arch_feature_index / @bitSizeOf(usize);
                    const bit_index = @intCast(ShiftInt, arch_feature_index % @bitSizeOf(usize));
                    return (set.ints[usize_index] & (@as(usize, 1) << bit_index)) != 0;
                }

                /// Adds the specified feature but not its dependencies.
                pub fn addFeature(set: *Set, arch_feature_index: Index) void {
                    const usize_index = arch_feature_index / @bitSizeOf(usize);
                    const bit_index = @intCast(ShiftInt, arch_feature_index % @bitSizeOf(usize));
                    set.ints[usize_index] |= @as(usize, 1) << bit_index;
                }

                /// Removes the specified feature but not its dependents.
                pub fn removeFeature(set: *Set, arch_feature_index: Index) void {
                    const usize_index = arch_feature_index / @bitSizeOf(usize);
                    const bit_index = @intCast(ShiftInt, arch_feature_index % @bitSizeOf(usize));
                    set.ints[usize_index] &= ~(@as(usize, 1) << bit_index);
                }

                pub fn populateDependencies(set: *Set, all_features_list: []const Cpu.Feature) void {
                    var old = set.ints;
                    while (true) {
                        for (all_features_list) |feature, index_usize| {
                            const index = @intCast(Index, index_usize);
                            if (set.isEnabled(index)) {
                                set.ints = @as(@Vector(usize_count, usize), set.ints) |
                                    @as(@Vector(usize_count, usize), feature.dependencies.ints);
                            }
                        }
                        const nothing_changed = mem.eql(usize, &old, &set.ints);
                        if (nothing_changed) return;
                        old = set.ints;
                    }
                }

                pub fn asBytes(set: *const Set) *const [byte_count]u8 {
                    return @ptrCast(*const [byte_count]u8, &set.ints);
                }

                pub fn eql(set: Set, other: Set) bool {
                    return mem.eql(usize, &set.ints, &other.ints);
                }
            };

            pub fn feature_set_fns(comptime F: type) type {
                return struct {
                    /// Populates only the feature bits specified.
                    pub fn featureSet(features: []const F) Set {
                        var x = Set.empty_workaround(); // TODO remove empty_workaround
                        for (features) |feature| {
                            x.addFeature(@enumToInt(feature));
                        }
                        return x;
                    }

                    pub fn featureSetHas(set: Set, feature: F) bool {
                        return set.isEnabled(@enumToInt(feature));
                    }
                };
            }
        };
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
        cpu_features: CpuFeatures,
    };

    pub const CpuFeatures = struct {
        /// The CPU to target. It has a set of features
        /// which are overridden with the `features` field.
        cpu: *const Cpu,

        /// Explicitly provide the entire CPU feature set.
        features: Cpu.Feature.Set,

        pub fn initFromCpu(arch: Arch, cpu: *const Cpu) CpuFeatures {
            var features = cpu.features;
            if (arch.subArchFeature()) |sub_arch_index| {
                features.addFeature(sub_arch_index);
            }
            features.populateDependencies(arch.allFeaturesList());
            return CpuFeatures{
                .cpu = cpu,
                .features = features,
            };
        }
    };

    pub const current = Target{
        .Cross = Cross{
            .arch = builtin.arch,
            .os = builtin.os,
            .abi = builtin.abi,
            .cpu_features = builtin.cpu_features,
        },
    };

    pub const stack_align = 16;

    pub fn getCpuFeatures(self: Target) CpuFeatures {
        return switch (self) {
            .Native => builtin.cpu_features,
            .Cross => |cross| cross.cpu_features,
        };
    }

    pub fn zigTriple(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{}{}-{}-{}", .{
            @tagName(self.getArch()),
            Target.archSubArchName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        });
    }

    /// Returned slice must be freed by the caller.
    pub fn vcpkgTriplet(allocator: *mem.Allocator, target: Target, linkage: std.build.VcpkgLinkage) ![]const u8 {
        const arch = switch (target.getArch()) {
            .i386 => "x86",
            .x86_64 => "x64",

            .arm,
            .armeb,
            .thumb,
            .thumbeb,
            .aarch64_32,
            => "arm",

            .aarch64,
            .aarch64_be,
            => "arm64",

            else => return error.VcpkgNoSuchArchitecture,
        };

        const os = switch (target.getOs()) {
            .windows => "windows",
            .linux => "linux",
            .macosx => "macos",
            else => return error.VcpkgNoSuchOs,
        };

        if (linkage == .Static) {
            return try mem.join(allocator, "-", &[_][]const u8{ arch, os, "static" });
        } else {
            return try mem.join(allocator, "-", &[_][]const u8{ arch, os });
        }
    }

    pub fn allocDescription(self: Target, allocator: *mem.Allocator) ![]u8 {
        // TODO is there anything else worthy of the description that is not
        // already captured in the triple?
        return self.zigTriple(allocator);
    }

    pub fn zigTripleNoSubArch(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{}-{}-{}", .{
            @tagName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        });
    }

    pub fn linuxTriple(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{}-{}-{}", .{
            @tagName(self.getArch()),
            @tagName(self.getOs()),
            @tagName(self.getAbi()),
        });
    }

    /// TODO: Support CPU features here?
    /// https://github.com/ziglang/zig/issues/4261
    pub fn parse(text: []const u8) !Target {
        var it = mem.separate(text, "-");
        const arch_name = it.next() orelse return error.MissingArchitecture;
        const os_name = it.next() orelse return error.MissingOperatingSystem;
        const abi_name = it.next();
        const arch = try parseArchSub(arch_name);

        var cross = Cross{
            .arch = arch,
            .cpu_features = arch.getBaselineCpuFeatures(),
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
            .hermit,
            .other,
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
            if (mem.startsWith(u8, text, field.name)) {
                if (field.field_type == void) {
                    return @as(Arch, @field(Arch, field.name));
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

    pub fn isMusl(self: Target) bool {
        return switch (self.getAbi()) {
            .musl, .musleabi, .musleabihf => true,
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

    pub fn supportsNewStackCall(self: Target) bool {
        return !self.isWasm();
    }

    pub const Executor = union(enum) {
        native,
        qemu: []const u8,
        wine: []const u8,
        wasmtime: []const u8,
        unavailable,
    };

    pub fn getExternalExecutor(self: Target) Executor {
        if (@as(@TagType(Target), self) == .Native) return .native;

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

        if (self.getOs() == .wasi) {
            switch (self.getArchPtrBitWidth()) {
                32 => return Executor{ .wasmtime = "wasmtime" },
                else => return .unavailable,
            }
        }

        return .unavailable;
    }
};

test "parseCpuFeatureSet" {
    const arch: Target.Arch = .x86_64;
    const baseline = arch.getBaselineCpuFeatures();
    const set = try arch.parseCpuFeatureSet(baseline.cpu, "-sse,-avx,-cx8");
    std.testing.expect(!Target.x86.featureSetHas(set, .sse));
    std.testing.expect(!Target.x86.featureSetHas(set, .avx));
    std.testing.expect(!Target.x86.featureSetHas(set, .cx8));
    // These are expected because they are part of the baseline
    std.testing.expect(Target.x86.featureSetHas(set, .cmov));
    std.testing.expect(Target.x86.featureSetHas(set, .fxsr));
}
