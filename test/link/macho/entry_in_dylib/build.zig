const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib = b.addSharedLibrary(.{
        .name = "bootstrap",
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    lib.addCSourceFile("bootstrap.c", &.{});
    lib.linkLibC();
    lib.linker_allow_shlib_undefined = true;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibrary(lib);
    exe.linkLibC();
    exe.entry_symbol_name = "_bootstrap";
    exe.forceUndefinedSymbol("_my_main");

    const check_exe = exe.checkObject();
    check_exe.checkStart("segname __TEXT");
    check_exe.checkNext("vmaddr {text_vmaddr}");

    check_exe.checkStart("sectname __stubs");
    check_exe.checkNext("addr {stubs_vmaddr}");

    check_exe.checkStart("cmd MAIN");
    check_exe.checkNext("entryoff {entryoff}");

    check_exe.checkComputeCompare("text_vmaddr entryoff +", .{
        .op = .eq,
        .value = .{ .variable = "stubs_vmaddr" }, // The entrypoint should be a synthetic stub
    });
    test_step.dependOn(&check_exe.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run.step);
}
