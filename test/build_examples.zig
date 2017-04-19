const std = @import("std");
const build = std.build;
const mem = std.mem;
const fmt = std.fmt;

pub fn addBuildExampleTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(BuildExamplesContext);
    *cases = BuildExamplesContext {
        .b = b,
        .step = b.step("test-build-examples", "Build the examples"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    cases.add("example/hello_world/hello.zig");
    cases.addC("example/hello_world/hello_libc.zig");
    cases.add("example/cat/main.zig");
    cases.add("example/guess_number/main.zig");

    return cases.step;
}

const BuildExamplesContext = struct {
    b: &build.Builder,
    step: &build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    pub fn addC(self: &BuildExamplesContext, root_src: []const u8) {
        self.addAllArgs(root_src, true);
    }

    pub fn add(self: &BuildExamplesContext, root_src: []const u8) {
        self.addAllArgs(root_src, false);
    }

    pub fn addAllArgs(self: &BuildExamplesContext, root_src: []const u8, link_libc: bool) {
        const b = self.b;

        for ([]bool{false, true}) |release| {
            const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "build {} ({})",
                root_src, if (release) "release" else "debug");
            if (const filter ?= self.test_filter) {
                if (mem.indexOf(u8, annotated_case_name, filter) == null)
                    continue;
            }

            const exe = b.addExecutable("test", root_src);
            exe.setRelease(release);
            if (link_libc) {
                exe.linkLibrary("c");
            }

            const log_step = b.addLog("PASS {}\n", annotated_case_name);
            log_step.step.dependOn(&exe.step);

            self.step.dependOn(&log_step.step);
        }
    }
};
