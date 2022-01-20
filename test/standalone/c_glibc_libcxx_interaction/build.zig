const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const standardTarget = b.standardTargetOptions(.{});

    // Compile a small example using std::condition_variable with different versions of glibc.
    // libc++ has different implementations of the wait_for method depending on the version of
    // glibc. For glibc >= 2.30 it uses pthread_cond_clockwait, which is not available earlier.
    // libc++ should recognize the version of glibc during compilation so that it can choose the
    // correct implementation, otherwise we get undefined symbols.
    const glibc_major_version = 2;
    for ([_]u8{ 13, 29, 30 }) |glibc_minor_version| {
        const exe_name = b.fmt("glibc_libcxx_interaction_{d}.{d}", .{ glibc_major_version, glibc_minor_version });
        const exe = b.addExecutable(exe_name, null);
        b.default_step.dependOn(&exe.step);

        exe.addCSourceFile("std_condition_variable.cpp", &[_][]const u8{});
        exe.setBuildMode(mode);
        exe.linkLibC();
        exe.linkSystemLibrary("c++");

        var target = standardTarget;
        target.glibc_version = std.builtin.Version{ .major = glibc_major_version, .minor = glibc_minor_version };
        exe.setTarget(target);
    }
}
