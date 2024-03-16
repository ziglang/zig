const std = @import("std");
const fs = std.fs;
const git = @import("Fetch/git.zig");
const ErrorBundle = std.zig.ErrorBundle;

allocator: std.mem.Allocator,
root: fs.Dir,

errors: std.ArrayListUnmanaged(Error) = .{},

pub const Error = union(enum) {
    unable_to_create_sym_link: struct {
        code: anyerror,
        target_path: []const u8,
        sym_link_path: []const u8,
    },
    unable_to_create_file: struct {
        code: anyerror,
        file_name: []const u8,
    },
};

pub fn init(allocator: std.mem.Allocator, root: fs.Dir) Self {
    return .{
        .allocator = allocator,
        .root = root,
    };
}

pub fn deinit(self: *Self) void {
    for (self.errors.items) |item| {
        switch (item) {
            .unable_to_create_sym_link => |info| {
                self.allocator.free(info.target_path);
                self.allocator.free(info.sym_link_path);
            },
            .unable_to_create_file => |info| {
                self.allocator.free(info.file_name);
            },
        }
    }
    self.errors.deinit(self.allocator);
    self.* = undefined;
}

const Self = @This();

pub fn tarball(self: *Self, reader: anytype) !void {
    const strip_components = 1;

    var file_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var link_name_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var iter = std.tar.iterator(reader, .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
    });
    while (true) {
        if (iter.next() catch |err| switch (err) {
            error.TarUnsupportedHeader => continue,
            else => return err,
        }) |entry| {
            switch (entry.kind) {
                .directory => {}, // skip empty
                .file => {
                    if (entry.size == 0 and entry.name.len == 0) continue;
                    const file_name = stripComponents(entry.name, strip_components);
                    if (file_name.len == 0) return error.BadFileName;
                    if (try self.createFile(file_name)) |file| {
                        defer file.close();
                        try entry.writeAll(file);
                    }
                },
                .sym_link => {
                    const file_name = stripComponents(entry.name, strip_components);
                    if (file_name.len == 0) return error.BadFileName;
                    const link_name = entry.link_name;
                    try self.symLink(link_name, file_name);
                },
            }
        } else break;
    }
}

pub fn gitPack(self: *Self, commit_oid: git.Oid, reader: anytype) !void {
    // Same interface as std.fs.Dir.createFile, symLink
    const inf = struct {
        parent: *Self,

        pub fn makePath(_: @This(), _: []const u8) !void {}

        pub fn createFile(t: @This(), sub_path: []const u8, _: fs.File.CreateFlags) !fs.File {
            return (try t.parent.createFile(sub_path)) orelse error.Skip;
        }

        pub fn symLink(t: @This(), target_path: []const u8, sym_link_path: []const u8, _: fs.Dir.SymLinkFlags) !void {
            try t.parent.symLink(target_path, sym_link_path);
        }
    }{ .parent = self };

    var pack_dir = try self.root.makeOpenPath(".git", .{});
    defer pack_dir.close();
    var pack_file = try pack_dir.createFile("pkg.pack", .{ .read = true });
    defer pack_file.close();
    var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
    try fifo.pump(reader, pack_file.writer());
    try pack_file.sync();

    var index_file = try pack_dir.createFile("pkg.idx", .{ .read = true });
    defer index_file.close();
    {
        var index_buffered_writer = std.io.bufferedWriter(index_file.writer());
        try git.indexPack(self.allocator, pack_file, index_buffered_writer.writer());
        try index_buffered_writer.flush();
        try index_file.sync();
    }

    {
        var repository = try git.Repository.init(self.allocator, pack_file, index_file);
        defer repository.deinit();
        try repository.checkout(inf, commit_oid);
    }

    try self.root.deleteTree(".git");
}

pub fn directory(self: *Self, source: fs.Dir) !void {
    var it = try source.walk(self.allocator);
    defer it.deinit();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {}, // omit empty directories
            .file => {
                try copyFile(source, entry.path, self.root, entry.path);
            },
            .sym_link => {
                var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
                const link_name = try source.readLink(entry.path, &buf);
                try self.symLink(link_name, entry.path);
            },
            else => return error.IllegalFileTypeInPackage,
        }
    }
}

pub fn hasErrors(self: *Self) bool {
    return self.errors.items.len > 0;
}

fn copyFile(source_dir: fs.Dir, source_path: []const u8, dest_dir: fs.Dir, dest_path: []const u8) !void {
    source_dir.copyFile(source_path, dest_dir, dest_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            if (fs.path.dirname(dest_path)) |dirname| try dest_dir.makePath(dirname);
            try source_dir.copyFile(source_path, dest_dir, dest_path, .{});
        },
        else => |e| return e,
    };
}

/// Returns fs.File on success, null on failure.
/// Errors are collected in errors list.
fn createFile(self: *Self, sub_path: []const u8) !?fs.File {
    return createFilePath(self.root, sub_path) catch |err| {
        try self.errors.append(self.allocator, .{ .unable_to_create_file = .{
            .code = err,
            .file_name = try self.allocator.dupe(u8, sub_path),
        } });
        return null;
    };
}

fn symLink(self: *Self, target_path: []const u8, sym_link_path: []const u8) !void {
    symLinkPath(self.root, target_path, sym_link_path) catch |err| {
        try self.errors.append(self.allocator, .{ .unable_to_create_sym_link = .{
            .code = err,
            .target_path = try self.allocator.dupe(u8, target_path),
            .sym_link_path = try self.allocator.dupe(u8, sym_link_path),
        } });
    };
}

fn createFilePath(dir: fs.Dir, sub_path: []const u8) !fs.File {
    return dir.createFile(sub_path, .{ .exclusive = true }) catch |err| switch (err) {
        error.FileNotFound => {
            if (std.fs.path.dirname(sub_path)) |dirname| try dir.makePath(dirname);
            return try dir.createFile(sub_path, .{ .exclusive = true });
        },
        else => |e| return e,
    };
}

fn symLinkPath(dir: fs.Dir, target_path: []const u8, sym_link_path: []const u8) !void {
    // TODO: if this would create a symlink to outside
    // the destination directory, fail with an error instead.
    dir.symLink(target_path, sym_link_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            if (fs.path.dirname(sym_link_path)) |dirname| try dir.makePath(dirname);
            try dir.symLink(target_path, sym_link_path, .{});
        },
        else => |e| return e,
    };
}

fn stripComponents(path: []const u8, count: u32) []const u8 {
    var i: usize = 0;
    var c = count;
    while (c > 0) : (c -= 1) {
        if (std.mem.indexOfScalarPos(u8, path, i, '/')) |pos| {
            i = pos + 1;
        } else {
            i = path.len;
            break;
        }
    }
    return path[i..];
}

const testing = std.testing;
const Unpack = @This();

test "tar stripComponents" {
    const expectEqualStrings = std.testing.expectEqualStrings;
    try expectEqualStrings("a/b/c", stripComponents("a/b/c", 0));
    try expectEqualStrings("b/c", stripComponents("a/b/c", 1));
    try expectEqualStrings("c", stripComponents("a/b/c", 2));
    try expectEqualStrings("", stripComponents("a/b/c", 3));
    try expectEqualStrings("", stripComponents("a/b/c", 4));
}

test gitPack {
    const paths: []const []const u8 = &.{
        "dir/file",
        "dir/subdir/file",
        "dir/subdir/file2",
        "dir2/file",
        "dir3/file",
        "dir3/file2",
        "file",
        "file2",
        "file3",
        "file4",
        "file5",
        "file6",
        "file7",
        "file8",
        "file9",
    };

    // load git pack with expected files
    const data = @embedFile("Fetch/git/testdata/testrepo.pack");
    var fbs = std.io.fixedBufferStream(data);

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    // unpack git pack
    {
        var unpack = Unpack{ .allocator = testing.allocator, .root = tmp.dir };
        defer unpack.deinit();
        const commit_id = try git.parseOid("dd582c0720819ab7130b103635bd7271b9fd4feb");
        try unpack.gitPack(commit_id, fbs.reader());
    }

    try expectDirFiles(tmp.dir, paths);
}

const TarHeader = std.tar.output.Header;

test tarball {
    const paths: []const []const u8 = &.{
        "dir/file",
        "dir1/dir2/file2",
        "dir3/dir4/dir5/file3",
        "file",
        "file2",
    };
    var buf: [paths.len * @sizeOf(TarHeader)]u8 = undefined;

    // create tarball
    try createTarball(paths, &buf);

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    // unpack tarball to tmp dir, will strip root dir
    {
        var fbs = std.io.fixedBufferStream(&buf);

        var unpack = Unpack{ .allocator = testing.allocator, .root = tmp.dir };
        defer unpack.deinit();
        try unpack.tarball(fbs.reader());
    }

    try expectDirFiles(tmp.dir, paths);
}

test directory {
    const paths: []const []const u8 = &.{
        "dir/file",
        "dir1/dir2/file2",
        "dir3/dir4/dir5/file3",
        "file",
        "file2",
    };

    var source = testing.tmpDir(.{ .iterate = true });
    defer source.cleanup();

    for (paths) |path| {
        const f = try createFilePath(source.dir, path);
        f.close();
    }

    var dest = testing.tmpDir(.{ .iterate = true });
    defer dest.cleanup();

    var unpack = Unpack{ .allocator = testing.allocator, .root = dest.dir };
    defer unpack.deinit();
    try unpack.directory(source.dir);

    try expectDirFiles(dest.dir, paths);
}

test "collect errors" {
    // Tarball with two files with same path.
    // Unpack will have 1 error in errors list.

    const paths: []const []const u8 = &.{
        "dir/file",
        "dir/file",
    };
    var buf: [paths.len * @sizeOf(TarHeader)]u8 = undefined;
    try createTarball(paths, &buf);

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    var fbs = std.io.fixedBufferStream(&buf);
    var unpack = Unpack{ .allocator = testing.allocator, .root = tmp.dir };
    defer unpack.deinit();
    try unpack.tarball(fbs.reader());

    try expectDirFiles(tmp.dir, paths[0..1]);

    try testing.expectEqual(1, unpack.errors.items.len);
    try testing.expectEqualStrings(paths[1], unpack.errors.items[0].unable_to_create_file.file_name);
}

fn createTarball(paths: []const []const u8, buf: []u8) !void {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();
    for (paths) |path| {
        var hdr = TarHeader.init();
        hdr.typeflag = .regular;
        try hdr.setPath("stripped_root", path);
        try hdr.updateChecksum();
        try writer.writeAll(std.mem.asBytes(&hdr));
    }
}

fn expectDirFiles(dir: fs.Dir, expected_files: []const []const u8) !void {
    var actual_files: std.ArrayListUnmanaged([]u8) = .{};
    defer actual_files.deinit(testing.allocator);
    defer for (actual_files.items) |file| testing.allocator.free(file);
    var walker = try dir.walk(testing.allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        const path = try testing.allocator.dupe(u8, entry.path);
        errdefer testing.allocator.free(path);
        std.mem.replaceScalar(u8, path, std.fs.path.sep, '/');
        try actual_files.append(testing.allocator, path);
    }
    std.mem.sortUnstable([]u8, actual_files.items, {}, struct {
        fn lessThan(_: void, a: []u8, b: []u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    try testing.expectEqualDeep(expected_files, actual_files.items);
}

// var buf: [256]u8 = undefined;
// std.debug.print("tmp dir: {s}\n", .{try tmp.dir.realpath(".", &buf)});
