const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const empty_c = b.addWriteFiles().add("empty.c", "");

    const foo_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    foo_mod.addCSourceFile(.{ .file = empty_c });

    const foo_lib = b.addLibrary(.{
        .name = "foo",
        .root_module = foo_mod,
        .linkage = .static,
    });

    const main_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
        .link_libc = true,
    });
    main_mod.addCSourceFile(.{ .file = b.addWriteFiles().add("main.c",
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

    const exe = b.addExecutable2(.{
        .name = "exe",
        .root_module = main_mod,
    });

    foo_lib.installHeadersDirectory(b.path("include"), "foo", .{ .exclude_extensions = &.{".ignore_me.h"} });
    foo_lib.installHeader(b.addWriteFiles().add("d.h",
        \\#define FOO_D "D"
        \\
    ), "foo/d.h");

    if (foo_lib.installed_headers_include_tree != null) std.debug.panic("include tree step was created before linking", .{});

    // Link before we have registered all headers for installation,
    // to verify that the lazily created write files step is properly taken into account.
    main_mod.linkLibrary(foo_lib);

    if (foo_lib.installed_headers_include_tree == null) std.debug.panic("include tree step was not created after linking", .{});

    foo_lib.installConfigHeader(b.addConfigHeader(.{
        .style = .blank,
        .include_path = "foo/config.h",
    }, .{
        .FOO_CONFIG_1 = "1",
        .FOO_CONFIG_2 = "2",
    }));

    const bar_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    bar_mod.addCSourceFile(.{ .file = empty_c });

    const bar_lib = b.addLibrary(.{
        .name = "bar",
        .root_module = bar_mod,
        .linkage = .static,
    });
    bar_lib.installHeader(b.addWriteFiles().add("bar.h",
        \\#define BAR_X "X"
        \\
    ), "bar.h");

    foo_lib.installLibraryHeaders(bar_lib);

    const run_exe = b.addRunArtifact(exe);
    run_exe.expectStdOutEqual("ABD12X");
    test_step.dependOn(&run_exe.step);

    const install_foo_lib = b.addInstallArtifact(foo_lib, .{
        .dest_dir = .{ .override = .{ .custom = "custom" } },
        .h_dir = .{ .override = .{ .custom = "custom/include" } },
        .implib_dir = .disabled,
        .pdb_dir = .disabled,
    });

    const check_exists = b.addExecutable2(.{
        .name = "check_exists",
        .root_module = b.createModule(.{
            .root_source_file = b.path("check_exists.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = .Debug,
        }),
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
    run_check_exists.step.dependOn(&install_foo_lib.step);
    test_step.dependOn(&run_check_exists.step);
}
