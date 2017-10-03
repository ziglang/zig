const Builder = @import("std").build.Builder;
const tests = @import("test/tests.zig");

pub fn build(b: &Builder) {
    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const with_lldb = b.option(bool, "with-lldb", "Run tests in LLDB to get a backtrace if one fails") ?? false;
    const test_step = b.step("test", "Run all the tests");

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
