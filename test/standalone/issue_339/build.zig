const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const obj = b.addObject("test", "test.zig");

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
