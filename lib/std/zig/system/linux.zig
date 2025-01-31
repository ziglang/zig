const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const io = std.io;
const fs = std.fs;
const fmt = std.fmt;
const testing = std.testing;
const Target = std.Target;
const assert = std.debug.assert;

const SparcCpuinfoImpl = struct {
    model: ?*const Target.Cpu.Model = null,
    is_64bit: bool = false,

    const cpu_names = .{
        .{ "SuperSparc", &Target.sparc.cpu.supersparc },
        .{ "HyperSparc", &Target.sparc.cpu.hypersparc },
        .{ "SpitFire", &Target.sparc.cpu.ultrasparc },
        .{ "BlackBird", &Target.sparc.cpu.ultrasparc },
        .{ "Sabre", &Target.sparc.cpu.ultrasparc },
        .{ "Hummingbird", &Target.sparc.cpu.ultrasparc },
        .{ "Cheetah", &Target.sparc.cpu.ultrasparc3 },
        .{ "Jalapeno", &Target.sparc.cpu.ultrasparc3 },
        .{ "Jaguar", &Target.sparc.cpu.ultrasparc3 },
        .{ "Panther", &Target.sparc.cpu.ultrasparc3 },
        .{ "Serrano", &Target.sparc.cpu.ultrasparc3 },
        .{ "UltraSparc T1", &Target.sparc.cpu.niagara },
        .{ "UltraSparc T2", &Target.sparc.cpu.niagara2 },
        .{ "UltraSparc T3", &Target.sparc.cpu.niagara3 },
        .{ "UltraSparc T4", &Target.sparc.cpu.niagara4 },
        .{ "UltraSparc T5", &Target.sparc.cpu.niagara4 },
        .{ "LEON", &Target.sparc.cpu.leon3 },
    };

    fn line_hook(self: *SparcCpuinfoImpl, key: []const u8, value: []const u8) !bool {
        if (mem.eql(u8, key, "cpu")) {
            inline for (cpu_names) |pair| {
                if (mem.indexOfPos(u8, value, 0, pair[0]) != null) {
                    self.model = pair[1];
                    break;
                }
            }
        } else if (mem.eql(u8, key, "type")) {
            self.is_64bit = mem.eql(u8, value, "sun4u") or mem.eql(u8, value, "sun4v");
        }

        return true;
    }

    fn finalize(self: *const SparcCpuinfoImpl, arch: Target.Cpu.Arch) ?Target.Cpu {
        // At the moment we only support 64bit SPARC systems.
        assert(self.is_64bit);

        const model = self.model orelse return null;
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const SparcCpuinfoParser = CpuinfoParser(SparcCpuinfoImpl);

test "cpuinfo: SPARC" {
    try testParser(SparcCpuinfoParser, .sparc64, &Target.sparc.cpu.niagara2,
        \\cpu             : UltraSparc T2 (Niagara2)
        \\fpu             : UltraSparc T2 integrated FPU
        \\pmu             : niagara2
        \\type            : sun4v
    );
}

const RiscvCpuinfoImpl = struct {
    model: ?*const Target.Cpu.Model = null,

    const cpu_names = .{
        .{ "sifive,u54", &Target.riscv.cpu.sifive_u54 },
        .{ "sifive,u7", &Target.riscv.cpu.sifive_7_series },
        .{ "sifive,u74", &Target.riscv.cpu.sifive_u74 },
        .{ "sifive,u74-mc", &Target.riscv.cpu.sifive_u74 },
    };

    fn line_hook(self: *RiscvCpuinfoImpl, key: []const u8, value: []const u8) !bool {
        if (mem.eql(u8, key, "uarch")) {
            inline for (cpu_names) |pair| {
                if (mem.eql(u8, value, pair[0])) {
                    self.model = pair[1];
                    break;
                }
            }
            return false;
        }

        return true;
    }

    fn finalize(self: *const RiscvCpuinfoImpl, arch: Target.Cpu.Arch) ?Target.Cpu {
        const model = self.model orelse return null;
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const RiscvCpuinfoParser = CpuinfoParser(RiscvCpuinfoImpl);

test "cpuinfo: RISC-V" {
    try testParser(RiscvCpuinfoParser, .riscv64, &Target.riscv.cpu.sifive_u74,
        \\processor : 0
        \\hart      : 1
        \\isa       : rv64imafdc
        \\mmu       : sv39
        \\isa-ext   :
        \\uarch     : sifive,u74-mc
    );
}

const PowerpcCpuinfoImpl = struct {
    model: ?*const Target.Cpu.Model = null,

    const cpu_names = .{
        .{ "604e", &Target.powerpc.cpu.@"604e" },
        .{ "604", &Target.powerpc.cpu.@"604" },
        .{ "7400", &Target.powerpc.cpu.@"7400" },
        .{ "7410", &Target.powerpc.cpu.@"7400" },
        .{ "7447", &Target.powerpc.cpu.@"7400" },
        .{ "7455", &Target.powerpc.cpu.@"7450" },
        .{ "G4", &Target.powerpc.cpu.g4 },
        .{ "POWER4", &Target.powerpc.cpu.@"970" },
        .{ "PPC970FX", &Target.powerpc.cpu.@"970" },
        .{ "PPC970MP", &Target.powerpc.cpu.@"970" },
        .{ "G5", &Target.powerpc.cpu.g5 },
        .{ "POWER5", &Target.powerpc.cpu.g5 },
        .{ "A2", &Target.powerpc.cpu.a2 },
        .{ "POWER6", &Target.powerpc.cpu.pwr6 },
        .{ "POWER7", &Target.powerpc.cpu.pwr7 },
        .{ "POWER8", &Target.powerpc.cpu.pwr8 },
        .{ "POWER8E", &Target.powerpc.cpu.pwr8 },
        .{ "POWER8NVL", &Target.powerpc.cpu.pwr8 },
        .{ "POWER9", &Target.powerpc.cpu.pwr9 },
        .{ "POWER10", &Target.powerpc.cpu.pwr10 },
    };

    fn line_hook(self: *PowerpcCpuinfoImpl, key: []const u8, value: []const u8) !bool {
        if (mem.eql(u8, key, "cpu")) {
            // The model name is often followed by a comma or space and extra
            // info.
            inline for (cpu_names) |pair| {
                const end_index = mem.indexOfAny(u8, value, ", ") orelse value.len;
                if (mem.eql(u8, value[0..end_index], pair[0])) {
                    self.model = pair[1];
                    break;
                }
            }

            // Stop the detection once we've seen the first core.
            return false;
        }

        return true;
    }

    fn finalize(self: *const PowerpcCpuinfoImpl, arch: Target.Cpu.Arch) ?Target.Cpu {
        const model = self.model orelse return null;
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const PowerpcCpuinfoParser = CpuinfoParser(PowerpcCpuinfoImpl);

test "cpuinfo: PowerPC" {
    try testParser(PowerpcCpuinfoParser, .powerpc, &Target.powerpc.cpu.@"970",
        \\processor : 0
        \\cpu       : PPC970MP, altivec supported
        \\clock     : 1250.000000MHz
        \\revision  : 1.1 (pvr 0044 0101)
    );
    try testParser(PowerpcCpuinfoParser, .powerpc64le, &Target.powerpc.cpu.pwr8,
        \\processor : 0
        \\cpu       : POWER8 (raw), altivec supported
        \\clock     : 2926.000000MHz
        \\revision  : 2.0 (pvr 004d 0200)
    );
}

const ArmCpuinfoImpl = struct {
    const num_cores = 4;

    cores: [num_cores]CoreInfo = undefined,
    core_no: usize = 0,
    have_fields: usize = 0,

    const CoreInfo = struct {
        architecture: u8 = 0,
        implementer: u8 = 0,
        variant: u8 = 0,
        part: u16 = 0,
        is_really_v6: bool = false,
    };

    const cpu_models = @import("arm.zig").cpu_models;

    fn addOne(self: *ArmCpuinfoImpl) void {
        if (self.have_fields == 4 and self.core_no < num_cores) {
            if (self.core_no > 0) {
                // Deduplicate the core info.
                for (self.cores[0..self.core_no]) |it| {
                    if (std.meta.eql(it, self.cores[self.core_no]))
                        return;
                }
            }
            self.core_no += 1;
        }
    }

    fn line_hook(self: *ArmCpuinfoImpl, key: []const u8, value: []const u8) !bool {
        const info = &self.cores[self.core_no];

        if (mem.eql(u8, key, "processor")) {
            // Handle both old-style and new-style cpuinfo formats.
            // The former prints a sequence of "processor: N" lines for each
            // core and then the info for the core that's executing this code(!)
            // while the latter prints the infos for each core right after the
            // "processor" key.
            self.have_fields = 0;
            self.cores[self.core_no] = .{};
        } else if (mem.eql(u8, key, "CPU implementer")) {
            info.implementer = try fmt.parseInt(u8, value, 0);
            self.have_fields += 1;
        } else if (mem.eql(u8, key, "CPU architecture")) {
            // "AArch64" on older kernels.
            info.architecture = if (mem.startsWith(u8, value, "AArch64"))
                8
            else
                try fmt.parseInt(u8, value, 0);
            self.have_fields += 1;
        } else if (mem.eql(u8, key, "CPU variant")) {
            info.variant = try fmt.parseInt(u8, value, 0);
            self.have_fields += 1;
        } else if (mem.eql(u8, key, "CPU part")) {
            info.part = try fmt.parseInt(u16, value, 0);
            self.have_fields += 1;
        } else if (mem.eql(u8, key, "model name")) {
            // ARMv6 cores report "CPU architecture" equal to 7.
            if (mem.indexOf(u8, value, "(v6l)")) |_| {
                info.is_really_v6 = true;
            }
        } else if (mem.eql(u8, key, "CPU revision")) {
            // This field is always the last one for each CPU section.
            _ = self.addOne();
        }

        return true;
    }

    fn finalize(self: *ArmCpuinfoImpl, arch: Target.Cpu.Arch) ?Target.Cpu {
        if (self.core_no == 0) return null;

        const is_64bit = switch (arch) {
            .aarch64, .aarch64_be => true,
            else => false,
        };

        var known_models: [num_cores]?*const Target.Cpu.Model = undefined;
        for (self.cores[0..self.core_no], 0..) |core, i| {
            known_models[i] = cpu_models.isKnown(.{
                .architecture = core.architecture,
                .implementer = core.implementer,
                .variant = core.variant,
                .part = core.part,
            }, is_64bit);
        }

        // XXX We pick the first core on big.LITTLE systems, hopefully the
        // LITTLE one.
        const model = known_models[0] orelse return null;
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const ArmCpuinfoParser = CpuinfoParser(ArmCpuinfoImpl);

test "cpuinfo: ARM" {
    try testParser(ArmCpuinfoParser, .arm, &Target.arm.cpu.arm1176jz_s,
        \\processor       : 0
        \\model name      : ARMv6-compatible processor rev 7 (v6l)
        \\BogoMIPS        : 997.08
        \\Features        : half thumb fastmult vfp edsp java tls
        \\CPU implementer : 0x41
        \\CPU architecture: 7
        \\CPU variant     : 0x0
        \\CPU part        : 0xb76
        \\CPU revision    : 7
    );
    try testParser(ArmCpuinfoParser, .arm, &Target.arm.cpu.cortex_a7,
        \\processor : 0
        \\model name : ARMv7 Processor rev 3 (v7l)
        \\BogoMIPS : 18.00
        \\Features : half thumb fastmult vfp edsp neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae
        \\CPU implementer : 0x41
        \\CPU architecture: 7
        \\CPU variant : 0x0
        \\CPU part : 0xc07
        \\CPU revision : 3
        \\
        \\processor : 4
        \\model name : ARMv7 Processor rev 3 (v7l)
        \\BogoMIPS : 90.00
        \\Features : half thumb fastmult vfp edsp neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae
        \\CPU implementer : 0x41
        \\CPU architecture: 7
        \\CPU variant : 0x2
        \\CPU part : 0xc0f
        \\CPU revision : 3
    );
    try testParser(ArmCpuinfoParser, .aarch64, &Target.aarch64.cpu.cortex_a72,
        \\processor       : 0
        \\BogoMIPS        : 108.00
        \\Features        : fp asimd evtstrm crc32 cpuid
        \\CPU implementer : 0x41
        \\CPU architecture: 8
        \\CPU variant     : 0x0
        \\CPU part        : 0xd08
        \\CPU revision    : 3
    );
}

fn testParser(
    parser: anytype,
    arch: Target.Cpu.Arch,
    expected_model: *const Target.Cpu.Model,
    input: []const u8,
) !void {
    var fbs = io.fixedBufferStream(input);
    const result = try parser.parse(arch, fbs.reader());
    try testing.expectEqual(expected_model, result.?.model);
    try testing.expect(expected_model.features.eql(result.?.features));
}

// The generic implementation of a /proc/cpuinfo parser.
// For every line it invokes the line_hook method with the key and value strings
// as first and second parameters. Returning false from the hook function stops
// the iteration without raising an error.
// When all the lines have been analyzed the finalize method is called.
fn CpuinfoParser(comptime impl: anytype) type {
    return struct {
        fn parse(arch: Target.Cpu.Arch, reader: anytype) anyerror!?Target.Cpu {
            var line_buf: [1024]u8 = undefined;
            var obj: impl = .{};

            while (true) {
                const line = (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) orelse break;
                const colon_pos = mem.indexOfScalar(u8, line, ':') orelse continue;
                const key = mem.trimRight(u8, line[0..colon_pos], " \t");
                const value = mem.trimLeft(u8, line[colon_pos + 1 ..], " \t");

                if (!try obj.line_hook(key, value))
                    break;
            }

            return obj.finalize(arch);
        }
    };
}

inline fn getAArch64CpuFeature(comptime feat_reg: []const u8) u64 {
    return asm ("mrs %[ret], " ++ feat_reg
        : [ret] "=r" (-> u64),
    );
}

pub fn detectNativeCpuAndFeatures() ?Target.Cpu {
    var f = fs.openFileAbsolute("/proc/cpuinfo", .{}) catch |err| switch (err) {
        else => return null,
    };
    defer f.close();

    const current_arch = builtin.cpu.arch;
    switch (current_arch) {
        .arm, .armeb, .thumb, .thumbeb => {
            return ArmCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        .aarch64, .aarch64_be => {
            const registers = [12]u64{
                getAArch64CpuFeature("MIDR_EL1"),
                getAArch64CpuFeature("ID_AA64PFR0_EL1"),
                getAArch64CpuFeature("ID_AA64PFR1_EL1"),
                getAArch64CpuFeature("ID_AA64DFR0_EL1"),
                getAArch64CpuFeature("ID_AA64DFR1_EL1"),
                getAArch64CpuFeature("ID_AA64AFR0_EL1"),
                getAArch64CpuFeature("ID_AA64AFR1_EL1"),
                getAArch64CpuFeature("ID_AA64ISAR0_EL1"),
                getAArch64CpuFeature("ID_AA64ISAR1_EL1"),
                getAArch64CpuFeature("ID_AA64MMFR0_EL1"),
                getAArch64CpuFeature("ID_AA64MMFR1_EL1"),
                getAArch64CpuFeature("ID_AA64MMFR2_EL1"),
            };

            const core = @import("arm.zig").aarch64.detectNativeCpuAndFeatures(current_arch, registers);
            return core;
        },
        .sparc64 => {
            return SparcCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => {
            return PowerpcCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        .riscv64, .riscv32 => {
            return RiscvCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        else => {},
    }

    return null;
}
