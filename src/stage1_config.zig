pub const have_llvm = true;
pub const version: [:0]const u8 = "0.0.0+zig0";
pub const semver: @import("std").SemanticVersion = .{
    .major = 0,
    .minor = 0,
    .patch = 0,
    .build = "zig0",
};
pub const log_scopes: []const []const u8 = &[_][]const u8{};
pub const zir_dumps: []const []const u8 = &[_][]const u8{};
pub const enable_tracy = false;
pub const is_stage1 = true;
pub const skip_non_native = false;
