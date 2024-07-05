const std = @import("std");
pub fn build(b: *std.Build) void {
    _ = b.path("this_path_is_missing_from_zon");
}
