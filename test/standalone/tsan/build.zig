const std = @import("std");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const is_macos = b.graph.host.result.os.tag == .macos;

    for ([_]struct { std.Target.Os.Tag, []const std.Target.Cpu.Arch }{
        // .s390x and mips64(el) fail to build
        .{ .linux, &.{ .aarch64, .aarch64_be, .loongarch64, .powerpc64, .powerpc64le, .riscv64, .x86_64 } },
        .{ .macos, &.{ .x86_64, .aarch64 } },

        // Missing system headers
        // https://github.com/ziglang/zig/issues/24736
        // .{ .freebsd, &.{ .aarch64, .powerpc64, .powerpc64le, .riscv64, .x86_64 } },
        // https://github.com/ziglang/zig/issues/24737
        // .{ .netbsd, &.{ .aarch64, .aarch64_be, .x86_64 } },

        // TSan doesn't have full support for windows yet.
        // .{ .windows, &.{ .aarch64, .x86_64 } },
    }) |entry| {
        switch (entry[0]) {
            // compiling tsan on macos requires system headers that aren't present during cross-compilation
            .macos => {
                if (!is_macos) continue;
                const target = b.resolveTargetQuery(.{});
                const exe = b.addExecutable(.{
                    .name = b.fmt("tsan_{s}_{s}", .{ @tagName(entry[0]), @tagName(target.result.cpu.arch) }),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path("main.zig"),
                        .target = target,
                        .optimize = .Debug,
                        .sanitize_thread = true,
                    }),
                });
                const install_exe = b.addInstallArtifact(exe, .{});
                test_step.dependOn(&install_exe.step);
            },
            else => for (entry[1]) |arch| {
                const target = b.resolveTargetQuery(.{
                    .os_tag = entry[0],
                    .cpu_arch = arch,
                });
                const exe = b.addExecutable(.{
                    .name = b.fmt("tsan_{s}_{s}", .{ @tagName(entry[0]), @tagName(arch) }),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path("main.zig"),
                        .target = target,
                        .optimize = .Debug,
                        .sanitize_thread = true,
                    }),
                });
                const install_exe = b.addInstallArtifact(exe, .{});
                test_step.dependOn(&install_exe.step);
            },
        }
    }
}
