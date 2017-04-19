const Builder = @import("std").build.Builder;
const tests = @import("test/tests.zig");

pub fn build(b: &Builder) {
    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const test_step = b.step("test", "Run all the tests");

    const self_hosted_tests = b.step("test-self-hosted", "Run the self-hosted tests");
    test_step.dependOn(self_hosted_tests);
    for ([]bool{false, true}) |release| {
        for ([]bool{false, true}) |link_libc| {
            const these_tests = b.addTest("test/self_hosted.zig");
            // TODO add prefix to test names
            // TODO pass test_filter to these_tests
            these_tests.setRelease(release);
            if (link_libc) {
                these_tests.linkLibrary("c");
            }
            self_hosted_tests.dependOn(&these_tests.step);
        }
    }

    const std_lib_tests = b.step("test-std", "Run the standard library tests");
    test_step.dependOn(std_lib_tests);
    for ([]bool{false, true}) |release| {
        for ([]bool{false, true}) |link_libc| {
            const these_tests = b.addTest("std/index.zig");
            // TODO add prefix to test names
            // TODO pass test_filter to these_tests
            these_tests.setRelease(release);
            if (link_libc) {
                these_tests.linkLibrary("c");
            }
            std_lib_tests.dependOn(&these_tests.step);
        }
    }

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter));
    test_step.dependOn(tests.addBuildExampleTests(b, test_filter));
    test_step.dependOn(tests.addCompileErrorTests(b, test_filter));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter));
    test_step.dependOn(tests.addDebugSafetyTests(b, test_filter));
}
