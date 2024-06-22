const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Here we are creating a module. Module is a set of files
    // that you can use to build executable or library, or import into other module.
    //
    // Here we are creating a module, but not exposing it to package manager.
    // To expose it to package manager, use function `addModule` and choose
    // a name for it. Packages that want to import your module will need to use
    // exactly this name in their build.zig:
    //
    // ```zig
    // // In your build.zig
    // const main_mod = b.addModule("main", .{ ... });
    //
    // // In their build.zig
    // const some_dep = b.dependency("...", .{ ... });
    // const some_mod = some_dep.module("main");
    // ```
    const main_mod = b.createModule(.{
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // You can import to this module other Zig modules, add C/C++ source files, link libraries,
    // and etc. To import Zig modules, use `addImport` function:
    //
    // ```zig
    // main_mod.addImport("some_mod", some_mod);
    // ```
    //
    // If they are added unconditionally, you can also import them during module creation instead:
    // ```zig
    // const main_mod = b.createModule(.{
    //     // ...
    //     .imports = &.{
    //         .{ .name = "some_mod", .module = some_mod },
    //         .{ .name = "another_mod", .module = another_mod },
    //     },
    // });
    // ```
    //
    // Now you can leverage it in your source code by using `@import("some_mod")`
    // syntax (get all definitions from root source file) or by using `@embedFile("some_mod")`
    // (get literal content of the root source file at comptime).
    //
    // Note that Zig's "std" module (a.k.a. standard library)
    // is always available, you don't need to import it manually.

    // After finishing module, we are building executable out of it.
    const exe = b.addExecutable2(.{
        .name = "$",
        .root_module = main_mod,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest2(.{
        .root_module = main_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Below we are doing same things, but for static library.
    const another_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "$",
        .root_module = another_mod,
        .linkage = .static,
    });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest2(.{
        .root_module = another_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    test_step.dependOn(&run_lib_unit_tests.step);
}
