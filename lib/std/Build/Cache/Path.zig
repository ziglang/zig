const Path = @This();
const std = @import("../../std.zig");
const assert = std.debug.assert;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;

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
    return initCwd("");
}

pub fn initCwd(sub_path: []const u8) Path {
    return .{ .root_dir = Cache.Directory.cwd(), .sub_path = sub_path };
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
    const new_sub_path = try fs.path.resolvePosix(arena, &.{ p.sub_path, sub_path });
    return .{
        .root_dir = p.root_dir,
        // Use "" instead of "." to represent `root_dir` itself.
        .sub_path = if (std.mem.eql(u8, new_sub_path, ".")) "" else new_sub_path,
    };
}

pub fn joinString(p: Path, gpa: Allocator, sub_path: []const u8) Allocator.Error![]u8 {
    const parts: []const []const u8 =
        if (p.sub_path.len == 0) &.{sub_path} else &.{ p.sub_path, sub_path };
    return p.root_dir.join(gpa, parts);
}

pub fn joinStringZ(p: Path, gpa: Allocator, sub_path: []const u8) Allocator.Error![:0]u8 {
    const parts: []const []const u8 =
        if (p.sub_path.len == 0) &.{sub_path} else &.{ p.sub_path, sub_path };
    return p.root_dir.joinZ(gpa, parts);
}

pub fn openFile(
    p: Path,
    sub_path: []const u8,
    flags: fs.File.OpenFlags,
) !fs.File {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.openFile(joined_path, flags);
}

pub fn openDir(
    p: Path,
    sub_path: []const u8,
    args: fs.Dir.OpenOptions,
) fs.Dir.OpenError!fs.Dir {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.openDir(joined_path, args);
}

pub fn makeOpenPath(p: Path, sub_path: []const u8, opts: fs.Dir.OpenOptions) !fs.Dir {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.makeOpenPath(joined_path, opts);
}

pub fn statFile(p: Path, sub_path: []const u8) !fs.Dir.Stat {
    var buf: [fs.max_path_bytes]u8 = undefined;
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
    buf: *[fs.max_path_bytes]u8,
) !fs.AtomicFile {
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.atomicFile(joined_path, options);
}

pub fn access(p: Path, sub_path: []const u8, flags: fs.File.OpenFlags) !void {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.access(joined_path, flags);
}

pub fn makePath(p: Path, sub_path: []const u8) !void {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const joined_path = if (p.sub_path.len == 0) sub_path else p: {
        break :p std.fmt.bufPrint(&buf, "{s}" ++ fs.path.sep_str ++ "{s}", .{
            p.sub_path, sub_path,
        }) catch return error.NameTooLong;
    };
    return p.root_dir.handle.makePath(joined_path);
}

pub fn toString(p: Path, allocator: Allocator) Allocator.Error![]u8 {
    return std.fmt.allocPrint(allocator, "{f}", .{p});
}

pub fn toStringZ(p: Path, allocator: Allocator) Allocator.Error![:0]u8 {
    return std.fmt.allocPrintSentinel(allocator, "{f}", .{p}, 0);
}

pub fn fmtEscapeString(path: Path) std.fmt.Formatter(Path, formatEscapeString) {
    return .{ .data = path };
}

pub fn formatEscapeString(path: Path, writer: *std.io.Writer) std.io.Writer.Error!void {
    if (path.root_dir.path) |p| {
        try std.zig.stringEscape(p, writer);
        if (path.sub_path.len > 0) try std.zig.stringEscape(fs.path.sep_str, writer);
    }
    if (path.sub_path.len > 0) {
        try std.zig.stringEscape(path.sub_path, writer);
    }
}

/// Deprecated, use double quoted escape to print paths.
pub fn fmtEscapeChar(path: Path) std.fmt.Formatter(Path, formatEscapeChar) {
    return .{ .data = path };
}

/// Deprecated, use double quoted escape to print paths.
pub fn formatEscapeChar(path: Path, writer: *std.io.Writer) std.io.Writer.Error!void {
    if (path.root_dir.path) |p| {
        for (p) |byte| try std.zig.charEscape(byte, writer);
        if (path.sub_path.len > 0) try writer.writeByte(fs.path.sep);
    }
    if (path.sub_path.len > 0) {
        for (path.sub_path) |byte| try std.zig.charEscape(byte, writer);
    }
}

pub fn format(self: Path, writer: *std.io.Writer) std.io.Writer.Error!void {
    if (std.fs.path.isAbsolute(self.sub_path)) {
        try writer.writeAll(self.sub_path);
        return;
    }
    if (self.root_dir.path) |p| {
        try writer.writeAll(p);
        if (self.sub_path.len > 0) {
            try writer.writeAll(fs.path.sep_str);
            try writer.writeAll(self.sub_path);
        }
        return;
    }
    if (self.sub_path.len > 0) {
        try writer.writeAll(self.sub_path);
        return;
    }
    try writer.writeByte('.');
}

pub fn eql(self: Path, other: Path) bool {
    return self.root_dir.eql(other.root_dir) and std.mem.eql(u8, self.sub_path, other.sub_path);
}

pub fn subPathOpt(self: Path) ?[]const u8 {
    return if (self.sub_path.len == 0) null else self.sub_path;
}

pub fn subPathOrDot(self: Path) []const u8 {
    return if (self.sub_path.len == 0) "." else self.sub_path;
}

pub fn stem(p: Path) []const u8 {
    return fs.path.stem(p.sub_path);
}

pub fn basename(p: Path) []const u8 {
    return fs.path.basename(p.sub_path);
}

/// Useful to make `Path` a key in `std.ArrayHashMap`.
pub const TableAdapter = struct {
    pub const Hash = std.hash.Wyhash;

    pub fn hash(self: TableAdapter, a: Cache.Path) u32 {
        _ = self;
        const seed = switch (@typeInfo(@TypeOf(a.root_dir.handle.fd))) {
            .pointer => @intFromPtr(a.root_dir.handle.fd),
            .int => @as(u32, @bitCast(a.root_dir.handle.fd)),
            else => @compileError("unimplemented hash function"),
        };
        return @truncate(Hash.hash(seed, a.sub_path));
    }
    pub fn eql(self: TableAdapter, a: Cache.Path, b: Cache.Path, b_index: usize) bool {
        _ = self;
        _ = b_index;
        return a.eql(b);
    }
};
