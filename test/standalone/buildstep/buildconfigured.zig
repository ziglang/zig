const config = @import("config.zig");

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    _ = b.step("test", "Test the program");
    _ = b.step(config.step_name, "the configured step");
}
