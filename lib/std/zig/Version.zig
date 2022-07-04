const std = @import("std");
const Version = @This();

version: std.builtin.Version,
opt_dev: ?Dev,

pub fn parse(version_str: []const u8) error{InvalidZigVersion}!Version {
    const semver = std.SemanticVersion.parse(version_str) catch |err| {
        std.log.err("zig version '{s}' is not a valid semantic version: {s}", .{ version_str, @errorName(err) });
        return error.InvalidZigVersion;
    };
    var result = Version{
        .version = .{
            .major = @intCast(u32, semver.major),
            .minor = @intCast(u32, semver.minor),
            .patch = @intCast(u32, semver.patch),
        },
        .opt_dev = null,
    };
    if (semver.pre) |pre| {
        const dev_prefix = "dev.";
        if (!std.mem.startsWith(u8, pre, dev_prefix)) {
            std.log.err("invalid zig version '{s}', expected '-{s}' after major/minor/patch, but got '-{s}'", .{ version_str, dev_prefix, pre });
            return error.InvalidZigVersion;
        }
        const commit_height_str = pre[dev_prefix.len..];
        const build = semver.build orelse {
            std.log.err("invalid zig version '{s}', has '-dev.COMMIT_HEIGHT' without a '+BUILD_REVISION'", .{version_str});
            return error.InvalidZigVersion;
        };
        if (build.len > 40) {
            std.log.err("invalid zig version '{s}', build revision is too long", .{version_str});
            return error.InvalidZigVersion;
        }
        result.opt_dev = .{
            .commit_height = std.fmt.parseInt(u32, commit_height_str, 10) catch |err| {
                std.log.err("invalid zig version '{s}', invalid commit height '{s}': {s}", .{ version_str, commit_height_str, @errorName(err) });
                return error.InvalidZigVersion;
            },
            .sha_buf = undefined,
            .sha_len = @intCast(u8, build.len),
        };
        std.mem.copy(u8, result.opt_dev.?.sha_buf[0..build.len], build);
    } else if (semver.build) |_| {
        std.log.err("invalid zig version '{s}', has '+BUILD_REVISION' without '-dev.COMMIT_HEIGHT'", .{version_str});
        return error.InvalidZigVersion;
    }

    return result;
}

pub const Order = enum {
    eq,
    lt,
    gt,
    /// Version and commit height are equal but hashes differ
    commit_height_eq,
    /// Version is equal but commit height is less than
    commit_height_lt,
    /// Version is equal but commit height is greater than
    commit_height_gt,

    pub fn inverse(self: Order) Order {
        return switch (self) {
            .eq => .eq,
            .lt => .gt,
            .gt => .lt,
            .commit_height_eq => .commit_height_eq,
            .commit_height_lt => .commit_height_gt,
            .commit_height_gt => .commit_height_lt,
        };
    }
};
pub fn order(left: Version, right: Version) Order {
    const left_dev = left.opt_dev orelse {
        if (right.opt_dev) |_| return right.order(left).inverse();
        return switch (left.version.order(right.version)) {
            .eq => .eq,
            .lt => .lt,
            .gt => .gt,
        };
    };
    const right_dev = right.opt_dev orelse return switch (left.version.order(right.version)) {
        // NOTE: .eq is supposed to map to .lt, the dev version is .lt if their semvers are equal
        .eq => .lt,
        .lt => .lt,
        .gt => .gt,
    };

    switch (left.version.order(right.version)) {
        .lt => return .lt,
        .gt => return .gt,
        .eq => {
            if (left_dev.commit_height > right_dev.commit_height)
                return .commit_height_gt;
            if (left_dev.commit_height < right_dev.commit_height)
                return .commit_height_lt;
            if (!std.mem.eql(u8, left_dev.sha(), right_dev.sha()))
                return .commit_height_eq;
            return .eq;
        },
    }
}

pub fn format(
    self: Version,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("{}.{}.{}", .{ self.version.major, self.version.minor, self.version.patch });
    if (self.opt_dev) |dev| {
        try writer.print("-dev.{d}+{s}", .{ dev.commit_height, dev.sha() });
    }
}

pub const Dev = struct {
    commit_height: u32,
    sha_buf: [40]u8,
    sha_len: u8,
    pub fn sha(self: *const Dev) []const u8 {
        return self.sha_buf[0..self.sha_len];
    }
};
