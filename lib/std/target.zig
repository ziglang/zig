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

        pub fn parse(text: []const u8) !Os {
            const info = @typeInfo(Os);
            inline for (info.Enum.fields) |field| {
                if (mem.eql(u8, text, field.name)) {
                    return @field(Os, field.name);
                }
            }
            return error.UnknownOperatingSystem;
        }
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

        pub fn default(arch: Cpu.Arch, target_os: Os) Abi {
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

        pub fn parse(text: []const u8) !Abi {
            const info = @typeInfo(Abi);
            inline for (info.Enum.fields) |field| {
                if (mem.eql(u8, text, field.name)) {
                    return @field(Abi, field.name);
                }
            }
            return error.UnknownApplicationBinaryInterface;
        }
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
        cpu: Cpu,
        os: Os,
        abi: Abi,
    };

    pub const Cpu = struct {
        /// Architecture
        arch: Arch,

        /// The CPU model to target. It has a set of features
        /// which are overridden with the `features` field.
        model: *const Model,

        /// An explicit list of the entire CPU feature set. It may differ from the specific CPU model's features.
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

                pub const needed_bit_count = 154;
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

                /// Adds the specified feature set but not its dependencies.
                pub fn addFeatureSet(set: *Set, other_set: Set) void {
                    set.ints = @as(@Vector(usize_count, usize), set.ints) |
                        @as(@Vector(usize_count, usize), other_set.ints);
                }

                /// Removes the specified feature but not its dependents.
                pub fn removeFeature(set: *Set, arch_feature_index: Index) void {
                    const usize_index = arch_feature_index / @bitSizeOf(usize);
                    const bit_index = @intCast(ShiftInt, arch_feature_index % @bitSizeOf(usize));
                    set.ints[usize_index] &= ~(@as(usize, 1) << bit_index);
                }

                pub fn populateDependencies(set: *Set, all_features_list: []const Cpu.Feature) void {
                    @setEvalBranchQuota(1000000);

                    var old = set.ints;
                    while (true) {
                        for (all_features_list) |feature, index_usize| {
                            const index = @intCast(Index, index_usize);
                            if (set.isEnabled(index)) {
                                set.addFeatureSet(feature.dependencies);
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

        pub const Arch = enum {
            arm,
            armeb,
            aarch64,
            aarch64_be,
            aarch64_32,
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
            thumb,
            thumbeb,
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
            kalimba,
            shave,
            lanai,
            wasm32,
            wasm64,
            renderscript32,
            renderscript64,

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

            pub fn isRISCV(arch: Arch) bool {
                return switch (arch) {
                    .riscv32, .riscv64 => true,
                    else => false,
                };
            }

            pub fn isMIPS(arch: Arch) bool {
                return switch (arch) {
                    .mips, .mipsel, .mips64, .mips64el => true,
                    else => false,
                };
            }

            pub fn parseCpuModel(arch: Arch, cpu_name: []const u8) !*const Cpu.Model {
                for (arch.allCpuModels()) |cpu| {
                    if (mem.eql(u8, cpu_name, cpu.name)) {
                        return cpu;
                    }
                }
                return error.UnknownCpu;
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

            /// All processors Zig is aware of, sorted lexicographically by name.
            pub fn allCpuModels(arch: Arch) []const *const Cpu.Model {
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

                    else => &[0]*const Model{},
                };
            }

            pub fn parse(text: []const u8) !Arch {
                const info = @typeInfo(Arch);
                inline for (info.Enum.fields) |field| {
                    if (mem.eql(u8, text, field.name)) {
                        return @as(Arch, @field(Arch, field.name));
                    }
                }
                return error.UnknownArchitecture;
            }
        };

        pub const Model = struct {
            name: []const u8,
            llvm_name: ?[:0]const u8,
            features: Feature.Set,

            pub fn toCpu(model: *const Model, arch: Arch) Cpu {
                var features = model.features;
                features.populateDependencies(arch.allFeaturesList());
                return .{
                    .arch = arch,
                    .model = model,
                    .features = features,
                };
            }
        };

        /// The "default" set of CPU features for cross-compiling. A conservative set
        /// of features that is expected to be supported on most available hardware.
        pub fn baseline(arch: Arch) Cpu {
            const S = struct {
                const generic_model = Model{
                    .name = "generic",
                    .llvm_name = null,
                    .features = Cpu.Feature.Set.empty,
                };
            };
            const model = switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.baseline,
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

                else => &S.generic_model,
            };
            return model.toCpu(arch);
        }
    };

    pub const current = Target{
        .Cross = Cross{
            .cpu = builtin.cpu,
            .os = builtin.os,
            .abi = builtin.abi,
        },
    };

    pub const stack_align = 16;

    pub fn zigTriple(self: Target, allocator: *mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{}-{}-{}", .{
            @tagName(self.getArch()),
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

    pub const ParseOptions = struct {
        /// This is sometimes called a "triple". It looks roughly like this:
        ///     riscv64-linux-gnu
        /// The fields are, respectively:
        /// * CPU Architecture
        /// * Operating System
        /// * C ABI (optional)
        arch_os_abi: []const u8,

        /// Looks like "name+a+b-c-d+e", where "name" is a CPU Model name, "a", "b", and "e"
        /// are examples of CPU features to add to the set, and "c" and "d" are examples of CPU features
        /// to remove from the set.
        cpu_features: []const u8 = "baseline",

        /// If this is provided, the function will populate some information about parsing failures,
        /// so that user-friendly error messages can be delivered.
        diagnostics: ?*Diagnostics = null,

        pub const Diagnostics = struct {
            /// If the architecture was determined, this will be populated.
            arch: ?Cpu.Arch = null,

            /// If the OS was determined, this will be populated.
            os: ?Os = null,

            /// If the ABI was determined, this will be populated.
            abi: ?Abi = null,

            /// If the CPU name was determined, this will be populated.
            cpu_name: ?[]const u8 = null,

            /// If error.UnknownCpuFeature is returned, this will be populated.
            unknown_feature_name: ?[]const u8 = null,
        };
    };

    pub fn parse(args: ParseOptions) !Target {
        var dummy_diags: ParseOptions.Diagnostics = undefined;
        var diags = args.diagnostics orelse &dummy_diags;

        var it = mem.separate(args.arch_os_abi, "-");
        const arch_name = it.next() orelse return error.MissingArchitecture;
        const arch = try Cpu.Arch.parse(arch_name);
        diags.arch = arch;

        const os_name = it.next() orelse return error.MissingOperatingSystem;
        const os = try Os.parse(os_name);
        diags.os = os;

        const abi_name = it.next();
        const abi = if (abi_name) |n| try Abi.parse(n) else Abi.default(arch, os);
        diags.abi = abi;

        if (it.next() != null) return error.UnexpectedExtraField;

        const all_features = arch.allFeaturesList();
        var index: usize = 0;
        while (index < args.cpu_features.len and
            args.cpu_features[index] != '+' and
            args.cpu_features[index] != '-')
        {
            index += 1;
        }
        const cpu_name = args.cpu_features[0..index];
        diags.cpu_name = cpu_name;

        const cpu: Cpu = if (mem.eql(u8, cpu_name, "baseline")) Cpu.baseline(arch) else blk: {
            const cpu_model = try arch.parseCpuModel(cpu_name);

            var set = cpu_model.features;
            while (index < args.cpu_features.len) {
                const op = args.cpu_features[index];
                index += 1;
                const start = index;
                while (index < args.cpu_features.len and
                    args.cpu_features[index] != '+' and
                    args.cpu_features[index] != '-')
                {
                    index += 1;
                }
                const feature_name = args.cpu_features[start..index];
                for (all_features) |feature, feat_index_usize| {
                    const feat_index = @intCast(Cpu.Feature.Set.Index, feat_index_usize);
                    if (mem.eql(u8, feature_name, feature.name)) {
                        switch (op) {
                            '+' => set.addFeature(feat_index),
                            '-' => set.removeFeature(feat_index),
                            else => unreachable,
                        }
                        break;
                    }
                } else {
                    diags.unknown_feature_name = feature_name;
                    return error.UnknownCpuFeature;
                }
            }
            set.populateDependencies(all_features);
            break :blk .{
                .arch = arch,
                .model = cpu_model,
                .features = set,
            };
        };
        var cross = Cross{
            .cpu = cpu,
            .os = os,
            .abi = abi,
        };
        return Target{ .Cross = cross };
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

    pub fn getCpu(self: Target) Cpu {
        return switch (self) {
            .Native => builtin.cpu,
            .Cross => |cross| cross.cpu,
        };
    }

    pub fn getArch(self: Target) Cpu.Arch {
        return self.getCpu().arch;
    }

    pub fn getAbi(self: Target) Abi {
        switch (self) {
            .Native => return builtin.abi,
            .Cross => |t| return t.abi,
        }
    }

    pub fn getObjectFormat(self: Target) ObjectFormat {
        switch (self) {
            .Native => return @import("builtin").object_format,
            .Cross => blk: {
                if (self.isWindows() or self.isUefi()) {
                    return .coff;
                } else if (self.isDarwin()) {
                    return .macho;
                }
                if (self.isWasm()) {
                    return .wasm;
                }
                return .elf;
            },
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

    pub fn isAndroid(self: Target) bool {
        return switch (self.getAbi()) {
            .android => true,
            else => false,
        };
    }

    pub fn isDragonFlyBSD(self: Target) bool {
        return switch (self.getOs()) {
            .dragonfly => true,
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

    pub const FloatAbi = enum {
        hard,
        soft,
        soft_fp,
    };

    pub fn getFloatAbi(self: Target) FloatAbi {
        return switch (self.getAbi()) {
            .gnueabihf,
            .eabihf,
            .musleabihf,
            => .hard,
            else => .soft,
        };
    }

    pub fn hasDynamicLinker(self: Target) bool {
        switch (self.getArch()) {
            .wasm32,
            .wasm64,
            => return false,
            else => {},
        }
        switch (self.getOs()) {
            .freestanding,
            .ios,
            .tvos,
            .watchos,
            .macosx,
            .uefi,
            .windows,
            .emscripten,
            .other,
            => return false,
            else => return true,
        }
    }

    /// Caller owns returned memory.
    pub fn getStandardDynamicLinkerPath(
        self: Target,
        allocator: *mem.Allocator,
    ) error{
        OutOfMemory,
        UnknownDynamicLinkerPath,
        TargetHasNoDynamicLinker,
    }![:0]u8 {
        const a = allocator;
        if (self.isAndroid()) {
            return mem.dupeZ(a, u8, if (self.getArchPtrBitWidth() == 64)
                "/system/bin/linker64"
            else
                "/system/bin/linker");
        }

        if (self.isMusl()) {
            var result = try std.Buffer.init(allocator, "/lib/ld-musl-");
            defer result.deinit();

            var is_arm = false;
            switch (self.getArch()) {
                .arm, .thumb => {
                    try result.append("arm");
                    is_arm = true;
                },
                .armeb, .thumbeb => {
                    try result.append("armeb");
                    is_arm = true;
                },
                else => |arch| try result.append(@tagName(arch)),
            }
            if (is_arm and self.getFloatAbi() == .hard) {
                try result.append("hf");
            }
            try result.append(".so.1");
            return result.toOwnedSlice();
        }

        switch (self.getOs()) {
            .freebsd => return mem.dupeZ(a, u8, "/libexec/ld-elf.so.1"),
            .netbsd => return mem.dupeZ(a, u8, "/libexec/ld.elf_so"),
            .dragonfly => return mem.dupeZ(a, u8, "/libexec/ld-elf.so.2"),
            .linux => switch (self.getArch()) {
                .i386,
                .sparc,
                .sparcel,
                => return mem.dupeZ(a, u8, "/lib/ld-linux.so.2"),

                .aarch64 => return mem.dupeZ(a, u8, "/lib/ld-linux-aarch64.so.1"),
                .aarch64_be => return mem.dupeZ(a, u8, "/lib/ld-linux-aarch64_be.so.1"),
                .aarch64_32 => return mem.dupeZ(a, u8, "/lib/ld-linux-aarch64_32.so.1"),

                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                => return mem.dupeZ(a, u8, switch (self.getFloatAbi()) {
                    .hard => "/lib/ld-linux-armhf.so.3",
                    else => "/lib/ld-linux.so.3",
                }),

                .mips,
                .mipsel,
                .mips64,
                .mips64el,
                => return error.UnknownDynamicLinkerPath,

                .powerpc => return mem.dupeZ(a, u8, "/lib/ld.so.1"),
                .powerpc64, .powerpc64le => return mem.dupeZ(a, u8, "/lib64/ld64.so.2"),
                .s390x => return mem.dupeZ(a, u8, "/lib64/ld64.so.1"),
                .sparcv9 => return mem.dupeZ(a, u8, "/lib64/ld-linux.so.2"),
                .x86_64 => return mem.dupeZ(a, u8, switch (self.getAbi()) {
                    .gnux32 => "/libx32/ld-linux-x32.so.2",
                    else => "/lib64/ld-linux-x86-64.so.2",
                }),

                .riscv32 => return mem.dupeZ(a, u8, "/lib/ld-linux-riscv32-ilp32.so.1"),
                .riscv64 => return mem.dupeZ(a, u8, "/lib/ld-linux-riscv64-lp64.so.1"),

                .wasm32,
                .wasm64,
                => return error.TargetHasNoDynamicLinker,

                .arc,
                .avr,
                .bpfel,
                .bpfeb,
                .hexagon,
                .msp430,
                .r600,
                .amdgcn,
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
                .renderscript32,
                .renderscript64,
                => return error.UnknownDynamicLinkerPath,
            },

            .freestanding,
            .ios,
            .tvos,
            .watchos,
            .macosx,
            .uefi,
            .windows,
            .emscripten,
            .other,
            => return error.TargetHasNoDynamicLinker,

            else => return error.UnknownDynamicLinkerPath,
        }
    }
};

test "Target.parse" {
    {
        const target = (try Target.parse(.{
            .arch_os_abi = "x86_64-linux-gnu",
            .cpu_features = "x86_64-sse-sse2-avx-cx8",
        })).Cross;

        std.testing.expect(target.os == .linux);
        std.testing.expect(target.abi == .gnu);
        std.testing.expect(target.cpu.arch == .x86_64);
        std.testing.expect(!Target.x86.featureSetHas(target.cpu.features, .sse));
        std.testing.expect(!Target.x86.featureSetHas(target.cpu.features, .avx));
        std.testing.expect(!Target.x86.featureSetHas(target.cpu.features, .cx8));
        std.testing.expect(Target.x86.featureSetHas(target.cpu.features, .cmov));
        std.testing.expect(Target.x86.featureSetHas(target.cpu.features, .fxsr));
    }
    {
        const target = (try Target.parse(.{
            .arch_os_abi = "arm-linux-musleabihf",
            .cpu_features = "generic+v8a",
        })).Cross;

        std.testing.expect(target.os == .linux);
        std.testing.expect(target.abi == .musleabihf);
        std.testing.expect(target.cpu.arch == .arm);
        std.testing.expect(target.cpu.model == &Target.arm.cpu.generic);
        std.testing.expect(Target.arm.featureSetHas(target.cpu.features, .v8a));
    }
}
