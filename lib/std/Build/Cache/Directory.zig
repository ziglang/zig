const Directory = @This();
const std = @import("../../std.zig");
const fs = std.fs;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

/// This field is redundant for operations that can act on the open directory handle
/// directly, but it is needed when passing the directory to a child process.
/// `null` means cwd.
path: ?[]const u8,
handle: fs.Dir,

pub fn clone(d: Directory, arena: Allocator) Allocator.Error!Directory {
    return .{
        .path = if (d.path) |p| try arena.dupe(u8, p) else null,
        .handle = d.handle,
    };
}

pub fn cwd() Directory {
    return .{
        .path = null,
        .handle = fs.cwd(),
    };
}

pub fn join(self: Directory, allocator: Allocator, paths: []const []const u8) ![]u8 {
    if (self.path) |p| {
        // TODO clean way to do this with only 1 allocation
        const part2 = try fs.path.join(allocator, paths);
        defer allocator.free(part2);
        return fs.path.join(allocator, &[_][]const u8{ p, part2 });
    } else {
        return fs.path.join(allocator, paths);
    }
}

pub fn joinZ(self: Directory, allocator: Allocator, paths: []const []const u8) ![:0]u8 {
    if (self.path) |p| {
        // TODO clean way to do this with only 1 allocation
        const part2 = try fs.path.join(allocator, paths);
        defer allocator.free(part2);
        return fs.path.joinZ(allocator, &[_][]const u8{ p, part2 });
    } else {
        return fs.path.joinZ(allocator, paths);
    }
}

/// Whether or not the handle should be closed, or the path should be freed
/// is determined by usage, however this function is provided for convenience
/// if it happens to be what the caller needs.
pub fn closeAndFree(self: *Directory, gpa: Allocator) void {
    self.handle.close();
    if (self.path) |p| gpa.free(p);
    self.* = undefined;
}

pub fn format(
    self: Directory,
    comptime fmt_string: []const u8,
    options: fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    if (fmt_string.len != 0) fmt.invalidFmtError(fmt_string, self);
    if (self.path) |p| {
        try writer.writeAll(p);
        try writer.writeAll(fs.path.sep_str);
    }
}

pub fn eql(self: Directory, other: Directory) bool {
    return self.handle.fd == other.handle.fd;
}
