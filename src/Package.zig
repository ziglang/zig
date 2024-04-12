pub const Module = @import("Package/Module.zig");

const package = @import("std").zig.package;
pub const Fetch = package.Fetch;
pub const build_zig_basename = package.build_zig_basename;
pub const Manifest = package.Manifest;
