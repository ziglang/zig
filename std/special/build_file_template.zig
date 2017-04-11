const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const release = b.option(bool, "release", "optimizations on and safety off") ?? false;

    var exe = b.addExe("src/main.zig", "YOUR_NAME_HERE");
    exe.setRelease(release);
}
