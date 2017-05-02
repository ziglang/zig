const Builder = @import("std").build.Builder;
const Mode = @import("builtin").Mode;

pub fn build(b: &Builder) {
    const release_safe = b.option(bool, "--release-safe", "optimizations on and safety on") ?? false;
    const release_fast = b.option(bool, "--release-fast", "optimizations on and safety off") ?? false;

    const build_mode = if (release_safe) {
        Mode.ReleaseSafe
    } else if (release_fast) {
        Mode.ReleaseFast
    } else {
        Mode.Debug
    };

    const exe = b.addExecutable("YOUR_NAME_HERE", "src/main.zig");
    exe.setBuildMode(build_mode);

    b.default_step.dependOn(&exe.step);
}
