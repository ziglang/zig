const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const bad_option = if (b.option(bool, "badoption", "Use this to emulator a bad build option")) |o| o else false;
    if (bad_option)
        std.build.fatalFullReport("got a bad build option!", .{});
}
