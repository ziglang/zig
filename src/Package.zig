pub const Module = @import("Package/Module.zig");
pub const Fetch = @import("Package/Fetch.zig");
pub const build_zig_basename = "build.zig";

test {
    _ = Fetch;
}
