const Builder = @import("std").build.Builder;
const tests = @import("test/tests.zig");
const os = @import("std").os;

pub fn build(b: &Builder) {
    const mode = b.standardReleaseOptions();

    var docgen_exe = b.addExecutable("docgen", "doc/docgen.zig");

    var docgen_cmd = b.addCommand(null, b.env_map, [][]const u8 {
        docgen_exe.getOutputPath(),
        "doc/langref.html.in",
        %%os.path.join(b.allocator, b.cache_root, "langref.html"),
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    var docgen_home_cmd = b.addCommand(null, b.env_map, [][]const u8 {
        docgen_exe.getOutputPath(),
        "doc/home.html.in",
        %%os.path.join(b.allocator, b.cache_root, "home.html"),
    });
    docgen_home_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);
    docs_step.dependOn(&docgen_home_cmd.step);

    var exe = b.addExecutable("zig", "src-self-hosted/main.zig");
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);
    b.default_step.dependOn(docs_step);

    b.installArtifact(exe);


    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const with_lldb = b.option(bool, "with-lldb", "Run tests in LLDB to get a backtrace if one fails") ?? false;
    const test_step = b.step("test", "Run all the tests");

    test_step.dependOn(docs_step);

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "test/behavior.zig", "behavior", "Run the behavior tests",
        with_lldb));

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "std/index.zig", "std", "Run the standard library tests",
        with_lldb));

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "std/special/compiler_rt/index.zig", "compiler-rt", "Run the compiler_rt tests",
        with_lldb));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter));
    test_step.dependOn(tests.addBuildExampleTests(b, test_filter));
    test_step.dependOn(tests.addCompileErrorTests(b, test_filter));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter));
    test_step.dependOn(tests.addDebugSafetyTests(b, test_filter));
    test_step.dependOn(tests.addParseCTests(b, test_filter));
}
