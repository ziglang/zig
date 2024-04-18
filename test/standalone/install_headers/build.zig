const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const empty_c = b.addWriteFiles().add("empty.c", "");

    const libfoo = b.addStaticLibrary(.{
        .name = "foo",
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    libfoo.addCSourceFile(.{ .file = empty_c });

    const exe = b.addExecutable(.{
        .name = "exe",
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
        .link_libc = true,
    });
    exe.addCSourceFile(.{ .file = b.addWriteFiles().add("main.c",
        \\#include <stdio.h>
        \\#include <foo/a.h>
        \\#include <foo/sub_dir/b.h>
        \\#include <foo/d.h>
        \\#include <foo/config.h>
        \\#include <bar.h>
        \\int main(void) {
        \\    printf(FOO_A FOO_B FOO_D FOO_CONFIG_1 FOO_CONFIG_2 BAR_X);
        \\    return 0;
        \\}
    ) });

    libfoo.installHeadersDirectory(b.path("include"), "foo", .{ .exclude_extensions = &.{".ignore_me.h"} });
    libfoo.installHeader(b.addWriteFiles().add("d.h",
        \\#define FOO_D "D"
        \\
    ), "foo/d.h");

    if (libfoo.installed_headers_include_tree != null) std.debug.panic("include tree step was created before linking", .{});

    // Link before we have registered all headers for installation,
    // to verify that the lazily created write files step is properly taken into account.
    exe.linkLibrary(libfoo);

    if (libfoo.installed_headers_include_tree == null) std.debug.panic("include tree step was not created after linking", .{});

    libfoo.installConfigHeader(b.addConfigHeader(.{
        .style = .blank,
        .include_path = "foo/config.h",
    }, .{
        .FOO_CONFIG_1 = "1",
        .FOO_CONFIG_2 = "2",
    }));

    const libbar = b.addStaticLibrary(.{
        .name = "bar",
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    libbar.addCSourceFile(.{ .file = empty_c });
    libbar.installHeader(b.addWriteFiles().add("bar.h",
        \\#define BAR_X "X"
        \\
    ), "bar.h");
    libfoo.installLibraryHeaders(libbar);

    const run_exe = b.addRunArtifact(exe);
    run_exe.expectStdOutEqual("ABD12X");
    test_step.dependOn(&run_exe.step);

    const install_libfoo = b.addInstallArtifact(libfoo, .{
        .dest_dir = .{ .override = .{ .custom = "custom" } },
        .h_dir = .{ .override = .{ .custom = "custom/include" } },
        .implib_dir = .disabled,
        .pdb_dir = .disabled,
    });
    const check_exists = b.addExecutable(.{
        .name = "check_exists",
        .root_source_file = b.path("check_exists.zig"),
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    const run_check_exists = b.addRunArtifact(check_exists);
    run_check_exists.addArgs(&.{
        "custom/include/foo/a.h",
        "!custom/include/foo/ignore_me.txt",
        "custom/include/foo/sub_dir/b.h",
        "!custom/include/foo/sub_dir/c.ignore_me.h",
        "custom/include/foo/d.h",
        "custom/include/foo/config.h",
        "custom/include/bar.h",
    });
    run_check_exists.setCwd(.{ .cwd_relative = b.getInstallPath(.prefix, "") });
    run_check_exists.expectExitCode(0);
    run_check_exists.step.dependOn(&install_libfoo.step);
    test_step.dependOn(&run_check_exists.step);
}
