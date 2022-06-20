const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.pagezero_size = 0x4000;

    var name: [16]u8 = undefined;
    std.mem.set(u8, &name, 0);
    std.mem.copy(u8, &name, "__PAGEZERO");
    const pagezero_seg = std.macho.segment_command_64{
        .cmdsize = @sizeOf(std.macho.segment_command_64),
        .segname = name,
        .vmaddr = 0,
        .vmsize = 0x4000,
        .fileoff = 0,
        .filesize = 0,
        .maxprot = 0,
        .initprot = 0,
        .nsects = 0,
        .flags = 0,
    };
    const check_file = std.build.CheckFileStep.create(b, exe.getOutputSource(), &[_][]const u8{std.mem.asBytes(&pagezero_seg)});

    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&check_file.step);
}
