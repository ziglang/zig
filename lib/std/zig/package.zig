pub const build_zig_basename = "build.zig";
pub const Fetch = @import("package/Fetch.zig");
pub const Manifest = @import("package/Manifest.zig");

test {
    _ = Manifest;
    _ = Fetch;
}
