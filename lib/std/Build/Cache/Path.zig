root_dir: Cache.Directory,
/// The path, relative to the root dir, that this `Path` represents.
/// Empty string means the root_dir is the path.
sub_path: []const u8 = "",

pub fn clone(p: Path, arena: Allocator) Allocator.Error!Path {
    return .{
        .root_dir = try p.root_dir.clone(arena),
        .sub_path = try arena.dupe(u8, p.sub_path),
    };
}

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

pub fn resolvePosix(p: Path, arena: Allocator, sub_path: []const u8) Allocator.Error!Path {
    if (sub_path.len == 0) return p;
    return .{
        .root_dir = p.root_dir,
        .sub_path = try fs.path.resolvePosix(arena, &.{ p.sub_path, sub_path }),
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
    buf: *[fs.MAX_PATH_BYTES]u8,
) !fs.AtomicFile {
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.atomicFile(joined_path, options);
}

pub fn access(p: Path, sub_path: []const u8, flags: fs.File.OpenFlags) !void {
    var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.access(joined_path, flags);
}

pub fn makePath(p: Path, sub_path: []const u8) !void {
    var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.makePath(joined_path);
}

pub fn format(
    self: Path,
    comptime fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (fmt_string.len == 1) {
        // Quote-escape the string.
        const stringEscape = std.zig.stringEscape;
        const f = switch (fmt_string[0]) {
            'q' => "",
            '\'' => '\'',
            else => @compileError("unsupported format string: " ++ fmt_string),
        };
        if (self.root_dir.path) |p| {
            try stringEscape(p, f, options, writer);
            if (self.sub_path.len > 0) try stringEscape(fs.path.sep_str, f, options, writer);
        }
        if (self.sub_path.len > 0) {
            try stringEscape(self.sub_path, f, options, writer);
        }
        return;
    }
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

const Path = @This();
const std = @import("../../std.zig");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
