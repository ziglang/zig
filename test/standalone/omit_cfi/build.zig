const std = @import("std");

pub fn build(b: *std.Build) void {
    inline for (.{
        .aarch64,
        .aarch64_be,
        .hexagon,
        .loongarch64,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .riscv32,
        .riscv64,
        .s390x,
        .sparc64,
        .x86,
        .x86_64,
    }) |arch| {
        const target = b.resolveTargetQuery(.{
            .cpu_arch = arch,
            .os_tag = .linux,
        });

        const omit_dbg = b.addExecutable(.{
            .name = b.fmt("{s}-linux-omit-dbg", .{@tagName(arch)}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("main.zig"),
                .target = target,
                .optimize = .Debug,
                // We are mainly concerned with CFI directives in our non-libc startup code and syscall
                // code, so make it explicit that we don't want libc.
                .link_libc = false,
                .strip = true,
            }),
        });

        const omit_uwt = b.addExecutable(.{
            .name = b.fmt("{s}-linux-omit-uwt", .{@tagName(arch)}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("main.zig"),
                .target = target,
                .optimize = .Debug,
                .link_libc = false,
                .unwind_tables = .none,
            }),
        });

        const omit_both = b.addExecutable(.{
            .name = b.fmt("{s}-linux-omit-both", .{@tagName(arch)}),
            .root_module = b.createModule(.{
                .root_source_file = b.path("main.zig"),
                .target = target,
                .optimize = .Debug,
                .link_libc = false,
                .strip = true,
                .unwind_tables = .none,
            }),
        });

        inline for (.{ omit_dbg, omit_uwt, omit_both }) |step| b.installArtifact(step);
    }
}
