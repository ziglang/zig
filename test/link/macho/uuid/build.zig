const std = @import("std");
const Builder = std.Build.Builder;
const CompileStep = std.Build.CompileStep;
const FileSource = std.Build.FileSource;
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    // We force cross-compilation to ensure we always pick a generic CPU with constant set of CPU features.
    const aarch64_macos = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    };

    testUuid(b, test_step, .ReleaseSafe, aarch64_macos);
    testUuid(b, test_step, .ReleaseFast, aarch64_macos);
    testUuid(b, test_step, .ReleaseSmall, aarch64_macos);

    const x86_64_macos = std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    };

    testUuid(b, test_step, .ReleaseSafe, x86_64_macos);
    testUuid(b, test_step, .ReleaseFast, x86_64_macos);
    testUuid(b, test_step, .ReleaseSmall, x86_64_macos);
}

fn testUuid(
    b: *std.Build,
    test_step: *std.Build.Step,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) void {
    // The calculated UUID value is independent of debug info and so it should
    // stay the same across builds.
    {
        const dylib = simpleDylib(b, optimize, target);
        const install_step = installWithRename(dylib, "test1.dylib");
        install_step.step.dependOn(&dylib.step);
    }
    {
        const dylib = simpleDylib(b, optimize, target);
        dylib.strip = true;
        const install_step = installWithRename(dylib, "test2.dylib");
        install_step.step.dependOn(&dylib.step);
    }

    const cmp_step = CompareUuid.create(b, "test1.dylib", "test2.dylib");
    test_step.dependOn(&cmp_step.step);
}

fn simpleDylib(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.Build.CompileStep {
    const dylib = b.addSharedLibrary(.{
        .name = "test",
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile("test.c", &.{});
    dylib.linkLibC();
    return dylib;
}

fn installWithRename(cs: *CompileStep, name: []const u8) *InstallWithRename {
    const step = InstallWithRename.create(cs.builder, cs.getOutputSource(), name);
    cs.builder.getInstallStep().dependOn(&step.step);
    return step;
}

const InstallWithRename = struct {
    pub const base_id = .custom;

    step: Step,
    builder: *Builder,
    source: FileSource,
    name: []const u8,

    pub fn create(
        builder: *Builder,
        source: FileSource,
        name: []const u8,
    ) *InstallWithRename {
        const self = builder.allocator.create(InstallWithRename) catch @panic("OOM");
        self.* = InstallWithRename{
            .builder = builder,
            .step = Step.init(.custom, builder.fmt("install and rename: {s} -> {s}", .{
                source.getDisplayName(),
                name,
            }), builder.allocator, make),
            .source = source,
            .name = builder.dupe(name),
        };
        return self;
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(InstallWithRename, "step", step);
        const source_path = self.source.getPath(self.builder);
        const target_path = self.builder.getInstallPath(.lib, self.name);
        self.builder.updateFile(source_path, target_path) catch |err| {
            std.log.err("Unable to rename: {s} -> {s}", .{ source_path, target_path });
            return err;
        };
    }
};

const CompareUuid = struct {
    pub const base_id = .custom;

    step: Step,
    builder: *Builder,
    lhs: []const u8,
    rhs: []const u8,

    pub fn create(builder: *Builder, lhs: []const u8, rhs: []const u8) *CompareUuid {
        const self = builder.allocator.create(CompareUuid) catch @panic("OOM");
        self.* = CompareUuid{
            .builder = builder,
            .step = Step.init(
                .custom,
                builder.fmt("compare uuid: {s} and {s}", .{
                    lhs,
                    rhs,
                }),
                builder.allocator,
                make,
            ),
            .lhs = lhs,
            .rhs = rhs,
        };
        return self;
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(CompareUuid, "step", step);
        const gpa = self.builder.allocator;

        var lhs_uuid: [16]u8 = undefined;
        const lhs_path = self.builder.getInstallPath(.lib, self.lhs);
        try parseUuid(gpa, lhs_path, &lhs_uuid);

        var rhs_uuid: [16]u8 = undefined;
        const rhs_path = self.builder.getInstallPath(.lib, self.rhs);
        try parseUuid(gpa, rhs_path, &rhs_uuid);

        try std.testing.expectEqualStrings(&lhs_uuid, &rhs_uuid);
    }

    fn parseUuid(gpa: std.mem.Allocator, path: []const u8, uuid: *[16]u8) anyerror!void {
        const max_bytes: usize = 20 * 1024 * 1024;
        const data = try std.fs.cwd().readFileAllocOptions(
            gpa,
            path,
            max_bytes,
            null,
            @alignOf(u64),
            null,
        );
        var stream = std.io.fixedBufferStream(data);
        const reader = stream.reader();

        const hdr = try reader.readStruct(std.macho.mach_header_64);
        if (hdr.magic != std.macho.MH_MAGIC_64) {
            return error.InvalidMagicNumber;
        }

        var it = std.macho.LoadCommandIterator{
            .ncmds = hdr.ncmds,
            .buffer = data[@sizeOf(std.macho.mach_header_64)..][0..hdr.sizeofcmds],
        };
        const cmd = while (it.next()) |cmd| switch (cmd.cmd()) {
            .UUID => break cmd.cast(std.macho.uuid_command).?,
            else => {},
        } else return error.UuidLoadCommandNotFound;
        std.mem.copy(u8, uuid, &cmd.uuid);
    }
};
