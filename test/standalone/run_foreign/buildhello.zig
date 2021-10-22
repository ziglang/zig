const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("hello", "hello.zig");
    exe.setTarget(b.standardTargetOptions(.{}));
    b.step("run", "Run the exe").dependOn(&exe.run().step);
}
