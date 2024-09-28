const std = @import("std");

pub fn build(b: *std.Build) void {
    if (b.option(bool, "resolve-path-during-config", "") orelse false) {
        const path = b.path("foo");
        _ = path.getPath(b);
        @panic("getPath didn't panic like it should have");
    }

    b.step("dangling_src_path", "").dependOn(
        &DanglingLazyPath.create(b, b.path("dangling")).step,
    );
    const write_files = b.addWriteFiles();
    const generated = write_files.add("generated", "foo");
    b.step("dangling_generated", "").dependOn(
        &DanglingLazyPath.create(b, generated).step,
    );
    b.step("dangling_cwd_relative", "").dependOn(
        &DanglingLazyPath.create(b, .{ .cwd_relative = "dangling" }).step,
    );
    //b.step("dangling_dependency", "").dependOn(
    //    &DanglingLazyPath.create(b, b.dependency("d").path("dangling") ).step,
    //);
}

const DanglingLazyPath = struct {
    step: std.Build.Step,
    lazy_path: std.Build.LazyPath,
    pub fn create(b: *std.Build, lazy_path: std.Build.LazyPath) *DanglingLazyPath {
        const d = b.allocator.create(DanglingLazyPath) catch @panic("OOM");
        d.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "dangling lazy path",
                .owner = b,
                .makeFn = make,
            }),
            .lazy_path = lazy_path,
        };
        // leave dangling by not calling lazy_path.addStepDependencies(d.step);
        return d;
    }
    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
        _ = options;
        const d: *DanglingLazyPath = @fieldParentPtr("step", step);
        _ = d.lazy_path.getPath(step.owner); // should panic
        @panic("getPath didn't panic like it should have");
    }
};
