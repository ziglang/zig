const tests = @import("tests.zig");

pub fn addCases(cases: &tests.BuildExamplesContext) {
    cases.add("example/hello_world/hello.zig");
    cases.addC("example/hello_world/hello_libc.zig");
    cases.add("example/cat/main.zig");
    cases.add("example/guess_number/main.zig");
    cases.addBuildFile("example/shared_library/build.zig");
    cases.addBuildFile("example/mix_o_files/build.zig");
    cases.addBuildFile("test/standalone/issue_339/build.zig");
    cases.addBuildFile("test/standalone/pkg_import/build.zig");
    cases.addBuildFile("test/standalone/use_alias/build.zig");
}
