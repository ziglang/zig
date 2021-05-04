const std = @import("std");

pub fn main() !void {
    const env_map = std.process.getEnvMap(std.testing.allocator) catch @panic("unable to get env map");
    try std.testing.expect(env_map.count() == 0);
}
