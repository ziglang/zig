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

        return Target.Cpu{
            .arch = arch,
            .model = self.model orelse Target.Cpu.Model.generic(arch),
            .features = Target.Cpu.Feature.Set.empty,
        };
    }
};

const SparcCpuinfoParser = CpuinfoParser(SparcCpuinfoImpl);

test "cpuinfo: SPARC" {
    const mock_cpuinfo =
        \\cpu             : UltraSparc T2 (Niagara2)
        \\fpu             : UltraSparc T2 integrated FPU
        \\pmu             : niagara2
        \\type            : sun4v
    ;

    var fbs = io.fixedBufferStream(mock_cpuinfo);

    const r = SparcCpuinfoParser.parse(.sparcv9, fbs.reader()) catch unreachable;
    testing.expectEqual(&Target.sparc.cpu.niagara2, r.?.model);
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

    switch (std.Target.current.cpu.arch) {
        .sparcv9 => return SparcCpuinfoParser.parse(.sparcv9, f.reader()) catch null,
        else => {},
    }

    return null;
}
