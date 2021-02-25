const Builder = @import("std").build.Builder;
const buildpkgs = @import("buildpkgs");

pub fn build(b: *Builder) void {
    if (comptime buildpkgs.has("androidbuild")) {
        const androidbuild = @import("androidbuild");
        androidbuild.makeApk(b);
    } else {
        const resolveandroid = b.addExecutable("resolveandroid", "resolveandroid.zig");
        resolveandroid.setBuildMode(b.standardReleaseOptions());

        const run_resolveandroid = resolveandroid.run();
        run_resolveandroid.addArg(b.zig_exe);

        const resolveandroid_step = b.step("test", "Resolve android and recompile build.zig");
        resolveandroid_step.dependOn(&run_resolveandroid.step);
    }
}
