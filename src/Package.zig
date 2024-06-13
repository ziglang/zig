pub const Module = @import("Package/Module.zig");
pub const Fetch = @import("Package/Fetch.zig");
pub const build_zig_basename = std.zig.build_file_basename;
pub const Manifest = std.zig.Manifest;

const std = @import("std");

test {
    _ = Fetch;
}
