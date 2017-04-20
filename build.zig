const Builder = @import("std").build.Builder;
const tests = @import("test/tests.zig");

pub fn build(b: &Builder) {
    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const test_step = b.step("test", "Run all the tests");

    const cleanup = b.addRemoveDirTree("test_artifacts");
    test_step.dependOn(&cleanup.step);

    cleanup.step.dependOn(tests.addPkgTests(b, test_filter,
        "test/behavior.zig", "behavior", "Run the behavior tests"));

    cleanup.step.dependOn(tests.addPkgTests(b, test_filter,
        "std/index.zig", "std", "Run the standard library tests"));

    cleanup.step.dependOn(tests.addCompareOutputTests(b, test_filter));
    cleanup.step.dependOn(tests.addBuildExampleTests(b, test_filter));
    cleanup.step.dependOn(tests.addCompileErrorTests(b, test_filter));
    cleanup.step.dependOn(tests.addAssembleAndLinkTests(b, test_filter));
    cleanup.step.dependOn(tests.addDebugSafetyTests(b, test_filter));
    cleanup.step.dependOn(tests.addParseHTests(b, test_filter));
}
