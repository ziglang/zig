const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const release = b.option(bool, "release", "optimizations on and safety off") ?? false;

    const exe = b.addExecutable("YOUR_NAME_HERE", "src/main.zig");
    exe.setRelease(release);

    b.default_step.dependOn(&exe.step);
}
