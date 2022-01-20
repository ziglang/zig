const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const standardTarget = b.standardTargetOptions(.{});

    const glibc_major_version = 2;
    for ([_]u8{ 13, 25, 31, 34 }) |glibc_minor_version| {
        const exe_name = b.fmt("assert_glibc_version_{d}.{d}", .{ glibc_major_version, glibc_minor_version });
        const exe = b.addExecutable(exe_name, null);
        b.default_step.dependOn(&exe.step);

        exe.addCSourceFile("assert_glibc_version.c", &[_][]const u8{"-std=c11"});
        exe.setBuildMode(mode);
        exe.linkLibC();

        var target = standardTarget;
        target.glibc_version = std.builtin.Version{ .major = glibc_major_version, .minor = glibc_minor_version };
        exe.setTarget(target);

        exe.defineCMacro("EXPECTED_GLIBC_MAJOR", b.fmt("{d}", .{glibc_major_version}));
        exe.defineCMacro("EXPECTED_GLIBC_MINOR", b.fmt("{d}", .{glibc_minor_version}));
    }
}
