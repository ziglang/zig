const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const opts = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("add", "add.zig", b.version(1, 0, 0));
    lib.setBuildMode(opts);

    const main = b.addExecutable("main", "main.zig");
    main.setBuildMode(opts);

    const run = b.addCommand(".", b.env_map, [][]const u8{
        main.getOutputPath(),
        lib.getOutputPath(),
    });
    run.step.dependOn(&lib.step);
    run.step.dependOn(&main.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run.step);
}
