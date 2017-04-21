const tests = @import("tests.zig");

pub fn addCases(cases: &tests.BuildExamplesContext) {
    cases.add("example/hello_world/hello.zig");
    cases.addC("example/hello_world/hello_libc.zig");
    cases.add("example/cat/main.zig");
    cases.add("example/guess_number/main.zig");
    cases.addBuildFile("example/shared_library/build.zig");
}
