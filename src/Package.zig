pub const Module = @import("Package/Module.zig");
pub const Fetch = @import("Package/Fetch.zig");
pub const build_zig_basename = "build.zig";
pub const Manifest = @import("Manifest.zig");

pub const Path = struct {
    root_dir: Cache.Directory,
    /// The path, relative to the root dir, that this `Path` represents.
    /// Empty string means the root_dir is the path.
    sub_path: []const u8 = "",

    pub fn cwd() Path {
        return .{ .root_dir = Cache.Directory.cwd() };
    }

    pub fn join(p: Path, arena: Allocator, sub_path: []const u8) Allocator.Error!Path {
        if (sub_path.len == 0) return p;
        const parts: []const []const u8 =
            if (p.sub_path.len == 0) &.{sub_path} else &.{ p.sub_path, sub_path };
        return .{
            .root_dir = p.root_dir,
            .sub_path = try fs.path.join(arena, parts),
        };
    }

    pub fn joinString(p: Path, allocator: Allocator, sub_path: []const u8) Allocator.Error![]u8 {
        const parts: []const []const u8 =
            if (p.sub_path.len == 0) &.{sub_path} else &.{ p.sub_path, sub_path };
        return p.root_dir.join(allocator, parts);
    }

    pub fn joinStringZ(p: Path, allocator: Allocator, sub_path: []const u8) Allocator.Error![:0]u8 {
        const parts: []const []const u8 =
            if (p.sub_path.len == 0) &.{sub_path} else &.{ p.sub_path, sub_path };
        return p.root_dir.joinZ(allocator, parts);
    }

    pub fn openFile(
        p: Path,
        sub_path: []const u8,
        flags: fs.File.OpenFlags,
    ) !fs.File {
        var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const joined_path = if (p.sub_path.len == 0) sub_path else p: {
            break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
                p.sub_path, sub_path,
            }) catch return error.NameTooLong;
        };
        return p.root_dir.handle.openFile(joined_path, flags);
    }

    pub fn makeOpenPath(p: Path, sub_path: []const u8, opts: fs.OpenDirOptions) !fs.Dir {
        var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const joined_path = if (p.sub_path.len == 0) sub_path else p: {
            break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
                p.sub_path, sub_path,
            }) catch return error.NameTooLong;
        };
        return p.root_dir.handle.makeOpenPath(joined_path, opts);
    }

    pub fn statFile(p: Path, sub_path: []const u8) !fs.Dir.Stat {
        var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const joined_path = if (p.sub_path.len == 0) sub_path else p: {
            break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
                p.sub_path, sub_path,
            }) catch return error.NameTooLong;
        };
        return p.root_dir.handle.statFile(joined_path);
    }

    pub fn atomicFile(
        p: Path,
        sub_path: []const u8,
        options: fs.Dir.AtomicFileOptions,
    ) !fs.AtomicFile {
        var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const joined_path = if (p.sub_path.len == 0) sub_path else p: {
            break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
                p.sub_path, sub_path,
            }) catch return error.NameTooLong;
        };
        return p.root_dir.handle.atomicFile(joined_path, options);
    }

    pub fn format(
        self: Path,
        comptime fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        if (fmt_string.len > 0)
            std.fmt.invalidFmtError(fmt_string, self);
        if (self.root_dir.path) |p| {
            try writer.writeAll(p);
            try writer.writeAll(fs.path.sep_str);
        }
        if (self.sub_path.len > 0) {
            try writer.writeAll(self.sub_path);
            try writer.writeAll(fs.path.sep_str);
        }
    }
};

const Package = @This();
const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Cache = std.Build.Cache;
