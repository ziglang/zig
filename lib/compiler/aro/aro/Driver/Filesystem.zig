const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

fn readFileFake(entries: []const Filesystem.Entry, path: []const u8, buf: []u8) ?[]const u8 {
    @setCold(true);
    for (entries) |entry| {
        if (mem.eql(u8, entry.path, path)) {
            const len = @min(entry.contents.len, buf.len);
            @memcpy(buf[0..len], entry.contents[0..len]);
            return buf[0..len];
        }
    }
    return null;
}

fn findProgramByNameFake(entries: []const Filesystem.Entry, name: []const u8, path: ?[]const u8, buf: []u8) ?[]const u8 {
    @setCold(true);
    if (mem.indexOfScalar(u8, name, '/') != null) {
        @memcpy(buf[0..name.len], name);
        return buf[0..name.len];
    }
    const path_env = path orelse return null;
    var fib = std.heap.FixedBufferAllocator.init(buf);

    var it = mem.tokenizeScalar(u8, path_env, std.fs.path.delimiter);
    while (it.next()) |path_dir| {
        defer fib.reset();
        const full_path = std.fs.path.join(fib.allocator(), &.{ path_dir, name }) catch continue;
        if (canExecuteFake(entries, full_path)) return full_path;
    }

    return null;
}

fn canExecuteFake(entries: []const Filesystem.Entry, path: []const u8) bool {
    @setCold(true);
    for (entries) |entry| {
        if (mem.eql(u8, entry.path, path)) {
            return entry.executable;
        }
    }
    return false;
}

fn existsFake(entries: []const Filesystem.Entry, path: []const u8) bool {
    @setCold(true);
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&buf);
    const resolved = std.fs.path.resolvePosix(fib.allocator(), &.{path}) catch return false;
    for (entries) |entry| {
        if (mem.eql(u8, entry.path, resolved)) return true;
    }
    return false;
}

fn canExecutePosix(path: []const u8) bool {
    std.os.access(path, std.os.X_OK) catch return false;
    // Todo: ensure path is not a directory
    return true;
}

/// TODO
fn canExecuteWindows(path: []const u8) bool {
    _ = path;
    return true;
}

/// TODO
fn findProgramByNameWindows(allocator: std.mem.Allocator, name: []const u8, path: ?[]const u8, buf: []u8) ?[]const u8 {
    _ = path;
    _ = buf;
    _ = name;
    _ = allocator;
    return null;
}

/// TODO: does WASI need special handling?
fn findProgramByNamePosix(name: []const u8, path: ?[]const u8, buf: []u8) ?[]const u8 {
    if (mem.indexOfScalar(u8, name, '/') != null) {
        @memcpy(buf[0..name.len], name);
        return buf[0..name.len];
    }
    const path_env = path orelse return null;
    var fib = std.heap.FixedBufferAllocator.init(buf);

    var it = mem.tokenizeScalar(u8, path_env, std.fs.path.delimiter);
    while (it.next()) |path_dir| {
        defer fib.reset();
        const full_path = std.fs.path.join(fib.allocator(), &.{ path_dir, name }) catch continue;
        if (canExecutePosix(full_path)) return full_path;
    }

    return null;
}

pub const Filesystem = union(enum) {
    real: void,
    fake: []const Entry,

    const Entry = struct {
        path: []const u8,
        contents: []const u8 = "",
        executable: bool = false,
    };

    const FakeDir = struct {
        entries: []const Entry,
        path: []const u8,

        fn iterate(self: FakeDir) FakeDir.Iterator {
            return .{
                .entries = self.entries,
                .base = self.path,
            };
        }

        const Iterator = struct {
            entries: []const Entry,
            base: []const u8,
            i: usize = 0,

            fn next(self: *@This()) !?std.fs.Dir.Entry {
                while (self.i < self.entries.len) {
                    const entry = self.entries[self.i];
                    self.i += 1;
                    if (entry.path.len == self.base.len) continue;
                    if (std.mem.startsWith(u8, entry.path, self.base)) {
                        const remaining = entry.path[self.base.len + 1 ..];
                        if (std.mem.indexOfScalar(u8, remaining, std.fs.path.sep) != null) continue;
                        const extension = std.fs.path.extension(remaining);
                        const kind: std.fs.Dir.Entry.Kind = if (extension.len == 0) .directory else .file;
                        return .{ .name = remaining, .kind = kind };
                    }
                }
                return null;
            }
        };
    };

    const Dir = union(enum) {
        dir: std.fs.Dir,
        fake: FakeDir,

        pub fn iterate(self: Dir) Iterator {
            return switch (self) {
                .dir => |dir| .{ .iterator = dir.iterate() },
                .fake => |fake| .{ .fake = fake.iterate() },
            };
        }

        pub fn close(self: *Dir) void {
            switch (self.*) {
                .dir => |*d| d.close(),
                .fake => {},
            }
        }
    };

    const Iterator = union(enum) {
        iterator: std.fs.Dir.Iterator,
        fake: FakeDir.Iterator,

        pub fn next(self: *Iterator) std.fs.Dir.Iterator.Error!?std.fs.Dir.Entry {
            return switch (self.*) {
                .iterator => |*it| it.next(),
                .fake => |*it| it.next(),
            };
        }
    };

    pub fn exists(fs: Filesystem, path: []const u8) bool {
        switch (fs) {
            .real => {
                std.os.access(path, std.os.F_OK) catch return false;
                return true;
            },
            .fake => |paths| return existsFake(paths, path),
        }
    }

    pub fn joinedExists(fs: Filesystem, parts: []const []const u8) bool {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var fib = std.heap.FixedBufferAllocator.init(&buf);
        const joined = std.fs.path.join(fib.allocator(), parts) catch return false;
        return fs.exists(joined);
    }

    pub fn canExecute(fs: Filesystem, path: []const u8) bool {
        return switch (fs) {
            .real => if (is_windows) canExecuteWindows(path) else canExecutePosix(path),
            .fake => |entries| canExecuteFake(entries, path),
        };
    }

    /// Search for an executable named `name` using platform-specific logic
    /// If it's found, write the full path to `buf` and return a slice of it
    /// Otherwise retun null
    pub fn findProgramByName(fs: Filesystem, allocator: std.mem.Allocator, name: []const u8, path: ?[]const u8, buf: []u8) ?[]const u8 {
        std.debug.assert(name.len > 0);
        return switch (fs) {
            .real => if (is_windows) findProgramByNameWindows(allocator, name, path, buf) else findProgramByNamePosix(name, path, buf),
            .fake => |entries| findProgramByNameFake(entries, name, path, buf),
        };
    }

    /// Read the file at `path` into `buf`.
    /// Returns null if any errors are encountered
    /// Otherwise returns a slice of `buf`. If the file is larger than `buf` partial contents are returned
    pub fn readFile(fs: Filesystem, path: []const u8, buf: []u8) ?[]const u8 {
        return switch (fs) {
            .real => {
                const file = std.fs.cwd().openFile(path, .{}) catch return null;
                defer file.close();

                const bytes_read = file.readAll(buf) catch return null;
                return buf[0..bytes_read];
            },
            .fake => |entries| readFileFake(entries, path, buf),
        };
    }

    pub fn openDir(fs: Filesystem, dir_name: []const u8) std.fs.Dir.OpenError!Dir {
        return switch (fs) {
            .real => .{ .dir = try std.fs.cwd().openDir(dir_name, .{ .access_sub_paths = false, .iterate = true }) },
            .fake => |entries| .{ .fake = .{ .entries = entries, .path = dir_name } },
        };
    }
};

test "Fake filesystem" {
    const fs: Filesystem = .{ .fake = &.{
        .{ .path = "/usr/bin" },
    } };
    try std.testing.expect(fs.exists("/usr/bin"));
    try std.testing.expect(fs.exists("/usr/bin/foo/.."));
    try std.testing.expect(!fs.exists("/usr/bin/bar"));
}
