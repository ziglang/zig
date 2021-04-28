const std = @import("std");
const mem = std.mem;
const io = std.io;
const fs = std.fs;
const fmt = std.fmt;
const testing = std.testing;

const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

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

        const model = self.model orelse Target.Cpu.Model.generic(arch);
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const SparcCpuinfoParser = CpuinfoParser(SparcCpuinfoImpl);

test "cpuinfo: SPARC" {
    try testParser(SparcCpuinfoParser, &Target.sparc.cpu.niagara2,
        \\cpu             : UltraSparc T2 (Niagara2)
        \\fpu             : UltraSparc T2 integrated FPU
        \\pmu             : niagara2
        \\type            : sun4v
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
        .{ "G4", &Target.powerpc.cpu.@"g4" },
        .{ "POWER4", &Target.powerpc.cpu.@"970" },
        .{ "PPC970FX", &Target.powerpc.cpu.@"970" },
        .{ "PPC970MP", &Target.powerpc.cpu.@"970" },
        .{ "G5", &Target.powerpc.cpu.@"g5" },
        .{ "POWER5", &Target.powerpc.cpu.@"g5" },
        .{ "A2", &Target.powerpc.cpu.@"a2" },
        .{ "POWER6", &Target.powerpc.cpu.@"pwr6" },
        .{ "POWER7", &Target.powerpc.cpu.@"pwr7" },
        .{ "POWER8", &Target.powerpc.cpu.@"pwr8" },
        .{ "POWER8E", &Target.powerpc.cpu.@"pwr8" },
        .{ "POWER8NVL", &Target.powerpc.cpu.@"pwr8" },
        .{ "POWER9", &Target.powerpc.cpu.@"pwr9" },
        .{ "POWER10", &Target.powerpc.cpu.@"pwr10" },
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
        const model = self.model orelse Target.Cpu.Model.generic(arch);
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const PowerpcCpuinfoParser = CpuinfoParser(PowerpcCpuinfoImpl);

test "cpuinfo: PowerPC" {
    try testParser(PowerpcCpuinfoParser, &Target.powerpc.cpu.@"970",
        \\processor	: 0
        \\cpu		: PPC970MP, altivec supported
        \\clock		: 1250.000000MHz
        \\revision	: 1.1 (pvr 0044 0101)
    );
    try testParser(PowerpcCpuinfoParser, &Target.powerpc.cpu.pwr8,
        \\processor	: 0
        \\cpu		: POWER8 (raw), altivec supported
        \\clock		: 2926.000000MHz
        \\revision	: 2.0 (pvr 004d 0200)
    );
}

fn testParser(parser: anytype, expected_model: *const Target.Cpu.Model, input: []const u8) !void {
    var fbs = io.fixedBufferStream(input);
    const result = try parser.parse(.powerpc, fbs.reader());
    testing.expectEqual(expected_model, result.?.model);
    testing.expect(expected_model.features.eql(result.?.features));
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

pub fn detectNativeCpuAndFeatures() ?Target.Cpu {
    var f = fs.openFileAbsolute("/proc/cpuinfo", .{ .intended_io_mode = .blocking }) catch |err| switch (err) {
        else => return null,
    };
    defer f.close();

    const current_arch = std.Target.current.cpu.arch;
    switch (current_arch) {
        .sparcv9 => {
            return SparcCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => {
            return PowerpcCpuinfoParser.parse(current_arch, f.reader()) catch null;
        },
        else => {},
    }

    return null;
}
