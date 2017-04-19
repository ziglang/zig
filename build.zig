const Builder = @import("std").build.Builder;
const tests = @import("test/tests.zig");

pub fn build(b: &Builder) {
    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const test_step = b.step("test", "Run all the tests");

    const run_tests_exe = b.addExecutable("run_tests", "test/run_tests.zig");

    const run_tests_cmd = b.addCommand(b.out_dir, b.env_map, "./run_tests", [][]const u8{});
    run_tests_cmd.step.dependOn(&run_tests_exe.step);

    const self_hosted_tests_debug_nolibc = b.addTest("test/self_hosted.zig");

    const self_hosted_tests_release_nolibc = b.addTest("test/self_hosted.zig");
    self_hosted_tests_release_nolibc.setRelease(true);

    const self_hosted_tests_debug_libc = b.addTest("test/self_hosted.zig");
    self_hosted_tests_debug_libc.linkLibrary("c");

    const self_hosted_tests_release_libc = b.addTest("test/self_hosted.zig");
    self_hosted_tests_release_libc.setRelease(true);
    self_hosted_tests_release_libc.linkLibrary("c");

    const self_hosted_tests = b.step("test-self-hosted", "Run the self-hosted tests");
    self_hosted_tests.dependOn(&self_hosted_tests_debug_nolibc.step);
    self_hosted_tests.dependOn(&self_hosted_tests_release_nolibc.step);
    self_hosted_tests.dependOn(&self_hosted_tests_debug_libc.step);
    self_hosted_tests.dependOn(&self_hosted_tests_release_libc.step);

    test_step.dependOn(self_hosted_tests);
    //test_step.dependOn(&run_tests_cmd.step);

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter));
    //test_step.dependOn(tests.addBuildExampleTests(b, test_filter));
}
