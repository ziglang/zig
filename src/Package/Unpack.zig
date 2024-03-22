const std = @import("std");
const fs = std.fs;
const git = @import("Fetch/git.zig");
const Filter = @import("Fetch.zig").Filter;

allocator: std.mem.Allocator,
root: fs.Dir,
package_sub_path: ?[]const u8 = null,
errors: Errors,

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

    pub fn excluded(self: Error, filter: Filter) bool {
        switch (self) {
            .unable_to_create_file => |info| return !filter.includePath(info.file_name),
            .unable_to_create_sym_link => |info| return !filter.includePath(info.target_path),
        }
    }
};

pub const Errors = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayListUnmanaged(Error) = .{},

    pub fn deinit(self: *Errors) void {
        for (self.list.items) |item| {
            self.free(item);
        }
        self.list.deinit(self.allocator);
        self.* = undefined;
    }

    fn free(self: *Errors, item: Error) void {
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

    pub fn count(self: *Errors) usize {
        return self.list.items.len;
    }

    fn createFile(self: *Errors, subdir_path: []const u8, file_path: []const u8, err: anyerror) !void {
        try self.list.append(self.allocator, .{ .unable_to_create_file = .{
            .code = err,
            .file_name = try std.fs.path.join(self.allocator, &.{ subdir_path, file_path }),
        } });
    }

    fn symLink(self: *Errors, subdir_path: []const u8, target_path: []const u8, sym_link_path: []const u8, err: anyerror) !void {
        try self.list.append(self.allocator, .{ .unable_to_create_sym_link = .{
            .code = err,
            .target_path = try self.allocator.dupe(u8, target_path),
            .sym_link_path = try std.fs.path.join(self.allocator, &.{ subdir_path, sym_link_path }),
        } });
    }

    fn filterWith(self: *Errors, filter: Filter) !void {
        var i = self.list.items.len;
        while (i > 0) {
            i -= 1;
            const item = self.list.items[i];
            if (item.excluded(filter)) {
                _ = self.list.swapRemove(i);
                self.free(item);
            }
        }
    }

    fn stripRoot(self: *Errors) !void {
        if (self.count() == 0) return;

        var old_list = self.list;
        self.list = .{};
        for (old_list.items) |item| {
            switch (item) {
                .unable_to_create_sym_link => |info| {
                    try self.symLink("", stripComponents(info.target_path, 1), info.sym_link_path, info.code);
                },
                .unable_to_create_file => |info| {
                    try self.createFile("", stripComponents(info.file_name, 1), info.code);
                },
            }
            self.free(item);
        }
        old_list.deinit(self.allocator);
    }
};

pub fn init(allocator: std.mem.Allocator, root: fs.Dir) Self {
    return .{
        .allocator = allocator,
        .errors = Errors{ .allocator = allocator },
        .root = root,
    };
}

pub fn deinit(self: *Self) void {
    self.errors.deinit();
    if (self.package_sub_path) |package_sub_path| {
        self.allocator.free(package_sub_path);
    }
}

const Self = @This();

pub fn tarball(self: *Self, reader: anytype) !void {
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
                    if (try self.createFile("", entry.name)) |file| {
                        defer file.close();
                        try entry.writeAll(file);
                    }
                },
                .sym_link => {
                    try self.symLink("", entry.link_name, entry.name);
                },
            }
        } else break;
    }
    try self.findPackageSubPath();
}

fn findPackageSubPath(self: *Self) !void {
    var iter = self.root.iterate();
    if (try iter.next()) |entry| {
        if (try iter.next() != null) return;
        if (entry.kind == .directory) { // single directory below root
            self.package_sub_path = try self.allocator.dupe(u8, entry.name);
            try self.errors.stripRoot();
        }
    }
}

test findPackageSubPath {
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    // folder1
    //     ├── folder2
    //     ├── file1
    //
    try tmp.dir.makePath("folder1/folder2");
    (try tmp.dir.createFile("folder1/file1", .{})).close();

    var unpack = init(testing.allocator, tmp.dir);
    try unpack.findPackageSubPath();
    // start at root returns folder1 as package root
    try testing.expectEqualStrings("folder1", unpack.package_sub_path.?);
    unpack.deinit();

    // start at folder1 returns null
    unpack = init(testing.allocator, try tmp.dir.openDir("folder1", .{ .iterate = true }));
    try unpack.findPackageSubPath();
    try testing.expect(unpack.package_sub_path == null);
    unpack.deinit();

    // start at folder1/folder2 returns null
    unpack = init(testing.allocator, try tmp.dir.openDir("folder1/folder2", .{ .iterate = true }));
    try unpack.findPackageSubPath();
    try testing.expect(unpack.package_sub_path == null);
    unpack.deinit();
}

pub fn gitPack(self: *Self, commit_oid: git.Oid, reader: anytype) !void {
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
        var iter = try repository.iterator(commit_oid);
        defer iter.deinit();
        while (try iter.next()) |entry| {
            switch (entry.type) {
                .file => {
                    if (try self.createFile(entry.path, entry.name)) |file| {
                        defer file.close();
                        try file.writeAll(entry.data);
                    }
                },
                .symlink => {
                    try self.symLink(entry.path, entry.data, entry.name);
                },
                else => {}, // skip empty directory
            }
        }
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
                try self.symLink("", link_name, entry.path);
            },
            else => return error.IllegalFileTypeInPackage,
        }
    }
}

pub fn hasErrors(self: *Self) bool {
    return self.errors.count() > 0;
}

pub fn filterErrors(self: *Self, filter: Filter) !void {
    try self.errors.filterWith(filter);
}

fn makePath(self: *Self, sub_path: []const u8) !fs.Dir {
    if (sub_path.len == 0) return self.root;
    try self.root.makePath(sub_path);
    return try self.root.openDir(sub_path, .{});
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
fn createFile(self: *Self, subdir_path: []const u8, file_path: []const u8) !?fs.File {
    return createFilePath(self.root, subdir_path, file_path) catch |err| {
        try self.errors.createFile(subdir_path, file_path, err);
        return null;
    };
}

fn symLink(self: *Self, subdir_path: []const u8, target_path: []const u8, sym_link_path: []const u8) !void {
    symLinkPath(self.root, subdir_path, target_path, sym_link_path) catch |err| {
        try self.errors.symLink(subdir_path, target_path, sym_link_path, err);
    };
}

fn createFilePath(root: fs.Dir, subdir_path: []const u8, file_path: []const u8) !fs.File {
    var dir = root;
    if (subdir_path.len > 0) {
        try dir.makePath(subdir_path);
        dir = try dir.openDir(subdir_path, .{});
    }

    return dir.createFile(file_path, .{ .exclusive = true }) catch |err| switch (err) {
        error.FileNotFound => {
            if (std.fs.path.dirname(file_path)) |dirname| try dir.makePath(dirname);
            return try dir.createFile(file_path, .{ .exclusive = true });
        },
        else => |e| return e,
    };
}

fn symLinkPath(root: fs.Dir, subdir_path: []const u8, target_path: []const u8, sym_link_path: []const u8) !void {
    // TODO: if this would create a symlink to outside
    // the destination directory, fail with an error instead.
    var dir = root;
    if (subdir_path.len > 0) {
        try dir.makePath(subdir_path);
        dir = try dir.openDir(subdir_path, .{});
    }

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
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    const repo = git.TestRepo;
    var stream = repo.stream();
    const reader = stream.reader();

    // Unpack git repo at commitID from reader
    {
        var unpack = Unpack.init(testing.allocator, tmp.dir);
        defer unpack.deinit();
        try unpack.gitPack(try repo.commitID(), reader);
    }

    try expectDirFiles(tmp.dir, repo.expected_files);
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

    // tarball with leading root folder
    {
        try createTarball("package_root", paths, &buf);
        var tmp = testing.tmpDir(.{ .iterate = true });
        defer tmp.cleanup();

        var fbs = std.io.fixedBufferStream(&buf);

        var unpack = Unpack.init(testing.allocator, tmp.dir);
        defer unpack.deinit();
        try unpack.tarball(fbs.reader());
        try testing.expectEqualStrings("package_root", unpack.package_sub_path.?);

        try expectDirFiles(try tmp.dir.openDir("package_root", .{ .iterate = true }), paths);
    }
    // tarball without root
    {
        try createTarball("", paths, &buf);
        var tmp = testing.tmpDir(.{ .iterate = true });
        defer tmp.cleanup();

        var fbs = std.io.fixedBufferStream(&buf);

        var unpack = Unpack.init(testing.allocator, tmp.dir);
        defer unpack.deinit();
        try unpack.tarball(fbs.reader());
        try testing.expect(unpack.package_sub_path == null);

        try expectDirFiles(tmp.dir, paths);
    }
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
        const f = try createFilePath(source.dir, "", path);
        f.close();
    }

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    var unpack = Unpack.init(testing.allocator, tmp.dir);
    defer unpack.deinit();
    try unpack.directory(source.dir);

    try expectDirFiles(tmp.dir, paths);
}

test "collect/filter errors" {
    const gpa = std.testing.allocator;

    // Tarball with duplicating files path to simulate fs write fail.
    const paths: []const []const u8 = &.{
        "dir/file",
        "dir1/file1",
        "dir/file",
        "dir1/file1",
    };
    var buf: [paths.len * @sizeOf(TarHeader)]u8 = undefined;
    try createTarball("package_root", paths, &buf);

    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    var fbs = std.io.fixedBufferStream(&buf);
    var unpack = Unpack.init(gpa, tmp.dir);
    defer unpack.deinit();
    try unpack.tarball(fbs.reader());
    try testing.expect(unpack.hasErrors());
    try testing.expectEqualStrings("package_root", unpack.package_sub_path.?);
    try expectDirFiles(try tmp.dir.openDir("package_root", .{ .iterate = true }), paths[0..2]);

    try testing.expectEqual(2, unpack.errors.count());
    try testing.expectEqualStrings("dir/file", unpack.errors.list.items[0].unable_to_create_file.file_name);
    try testing.expectEqualStrings("dir1/file1", unpack.errors.list.items[1].unable_to_create_file.file_name);

    {
        var filter: Filter = .{};
        defer filter.include_paths.deinit(gpa);

        // no filter all paths are included
        try unpack.filterErrors(filter);
        try testing.expectEqual(2, unpack.errors.count());

        // dir1 is included, dir excluded
        try filter.include_paths.put(gpa, "dir1", {});
        try unpack.filterErrors(filter);
        try testing.expectEqual(1, unpack.errors.count());
        try testing.expectEqualStrings("dir1/file1", unpack.errors.list.items[0].unable_to_create_file.file_name);
    }
    {
        var filter: Filter = .{};
        defer filter.include_paths.deinit(gpa);

        // only src included that filters all error paths
        try filter.include_paths.put(gpa, "src", {});
        try unpack.filterErrors(filter);
        try testing.expectEqual(0, unpack.errors.count());
    }
}

fn createTarball(prefix: []const u8, paths: []const []const u8, buf: []u8) !void {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();
    for (paths) |path| {
        var hdr = TarHeader.init();
        hdr.typeflag = .regular;
        if (prefix.len > 0) {
            try hdr.setPath(prefix, path);
        } else {
            hdr.setName(path);
        }
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
