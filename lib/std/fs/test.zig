const std = @import("../std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const fs = std.fs;
const mem = std.mem;
const wasi = std.os.wasi;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;

const ArenaAllocator = std.heap.ArenaAllocator;
const Dir = std.fs.Dir;
const File = std.fs.File;
const tmpDir = testing.tmpDir;
const SymLinkFlags = std.fs.Dir.SymLinkFlags;

const PathType = enum {
    relative,
    absolute,
    unc,

    pub fn isSupported(self: PathType, target_os: std.Target.Os) bool {
        return switch (self) {
            .relative => true,
            .absolute => std.os.isGetFdPathSupportedOnTarget(target_os),
            .unc => target_os.tag == .windows,
        };
    }

    pub const TransformError = posix.RealPathError || error{OutOfMemory};
    pub const TransformFn = fn (allocator: mem.Allocator, dir: Dir, relative_path: [:0]const u8) TransformError![:0]const u8;

    pub fn getTransformFn(comptime path_type: PathType) TransformFn {
        switch (path_type) {
            .relative => return struct {
                fn transform(allocator: mem.Allocator, dir: Dir, relative_path: [:0]const u8) TransformError![:0]const u8 {
                    _ = allocator;
                    _ = dir;
                    return relative_path;
                }
            }.transform,
            .absolute => return struct {
                fn transform(allocator: mem.Allocator, dir: Dir, relative_path: [:0]const u8) TransformError![:0]const u8 {
                    // The final path may not actually exist which would cause realpath to fail.
                    // So instead, we get the path of the dir and join it with the relative path.
                    var fd_path_buf: [fs.max_path_bytes]u8 = undefined;
                    const dir_path = try std.os.getFdPath(dir.fd, &fd_path_buf);
                    return fs.path.joinZ(allocator, &.{ dir_path, relative_path });
                }
            }.transform,
            .unc => return struct {
                fn transform(allocator: mem.Allocator, dir: Dir, relative_path: [:0]const u8) TransformError![:0]const u8 {
                    // Any drive absolute path (C:\foo) can be converted into a UNC path by
                    // using '127.0.0.1' as the server name and '<drive letter>$' as the share name.
                    var fd_path_buf: [fs.max_path_bytes]u8 = undefined;
                    const dir_path = try std.os.getFdPath(dir.fd, &fd_path_buf);
                    const windows_path_type = windows.getUnprefixedPathType(u8, dir_path);
                    switch (windows_path_type) {
                        .unc_absolute => return fs.path.joinZ(allocator, &.{ dir_path, relative_path }),
                        .drive_absolute => {
                            // `C:\<...>` -> `\\127.0.0.1\C$\<...>`
                            const prepended = "\\\\127.0.0.1\\";
                            var path = try fs.path.joinZ(allocator, &.{ prepended, dir_path, relative_path });
                            path[prepended.len + 1] = '$';
                            return path;
                        },
                        else => unreachable,
                    }
                }
            }.transform,
        }
    }
};

const TestContext = struct {
    path_type: PathType,
    path_sep: u8,
    arena: ArenaAllocator,
    tmp: testing.TmpDir,
    dir: std.fs.Dir,
    transform_fn: *const PathType.TransformFn,

    pub fn init(path_type: PathType, path_sep: u8, allocator: mem.Allocator, transform_fn: *const PathType.TransformFn) TestContext {
        const tmp = tmpDir(.{ .iterate = true });
        return .{
            .path_type = path_type,
            .path_sep = path_sep,
            .arena = ArenaAllocator.init(allocator),
            .tmp = tmp,
            .dir = tmp.dir,
            .transform_fn = transform_fn,
        };
    }

    pub fn deinit(self: *TestContext) void {
        self.arena.deinit();
        self.tmp.cleanup();
    }

    /// Returns the `relative_path` transformed into the TestContext's `path_type`,
    /// with any supported path separators replaced by `path_sep`.
    /// The result is allocated by the TestContext's arena and will be free'd during
    /// `TestContext.deinit`.
    pub fn transformPath(self: *TestContext, relative_path: [:0]const u8) ![:0]const u8 {
        const allocator = self.arena.allocator();
        const transformed_path = try self.transform_fn(allocator, self.dir, relative_path);
        if (native_os == .windows) {
            const transformed_sep_path = try allocator.dupeZ(u8, transformed_path);
            std.mem.replaceScalar(u8, transformed_sep_path, switch (self.path_sep) {
                '/' => '\\',
                '\\' => '/',
                else => unreachable,
            }, self.path_sep);
            return transformed_sep_path;
        }
        return transformed_path;
    }

    /// Replaces any path separators with the canonical path separator for the platform
    /// (e.g. all path separators are converted to `\` on Windows).
    /// If path separators are replaced, then the result is allocated by the
    /// TestContext's arena and will be free'd during `TestContext.deinit`.
    pub fn toCanonicalPathSep(self: *TestContext, path: [:0]const u8) ![:0]const u8 {
        if (native_os == .windows) {
            const allocator = self.arena.allocator();
            const transformed_sep_path = try allocator.dupeZ(u8, path);
            std.mem.replaceScalar(u8, transformed_sep_path, '/', '\\');
            return transformed_sep_path;
        }
        return path;
    }
};

/// `test_func` must be a function that takes a `*TestContext` as a parameter and returns `!void`.
/// `test_func` will be called once for each PathType that the current target supports,
/// and will be passed a TestContext that can transform a relative path into the path type under test.
/// The TestContext will also create a tmp directory for you (and will clean it up for you too).
fn testWithAllSupportedPathTypes(test_func: anytype) !void {
    try testWithPathTypeIfSupported(.relative, '/', test_func);
    try testWithPathTypeIfSupported(.absolute, '/', test_func);
    try testWithPathTypeIfSupported(.unc, '/', test_func);
    try testWithPathTypeIfSupported(.relative, '\\', test_func);
    try testWithPathTypeIfSupported(.absolute, '\\', test_func);
    try testWithPathTypeIfSupported(.unc, '\\', test_func);
}

fn testWithPathTypeIfSupported(comptime path_type: PathType, comptime path_sep: u8, test_func: anytype) !void {
    if (!(comptime path_type.isSupported(builtin.os))) return;
    if (!(comptime fs.path.isSep(path_sep))) return;

    var ctx = TestContext.init(path_type, path_sep, testing.allocator, path_type.getTransformFn());
    defer ctx.deinit();

    try test_func(&ctx);
}

// For use in test setup.  If the symlink creation fails on Windows with
// AccessDenied, then make the test failure silent (it is not a Zig failure).
fn setupSymlink(dir: Dir, target: []const u8, link: []const u8, flags: SymLinkFlags) !void {
    return dir.symLink(target, link, flags) catch |err| switch (err) {
        // Symlink requires admin privileges on windows, so this test can legitimately fail.
        error.AccessDenied => if (native_os == .windows) return error.SkipZigTest else return err,
        else => return err,
    };
}

// For use in test setup.  If the symlink creation fails on Windows with
// AccessDenied, then make the test failure silent (it is not a Zig failure).
fn setupSymlinkAbsolute(target: []const u8, link: []const u8, flags: SymLinkFlags) !void {
    return fs.symLinkAbsolute(target, link, flags) catch |err| switch (err) {
        error.AccessDenied => if (native_os == .windows) return error.SkipZigTest else return err,
        else => return err,
    };
}

test "Dir.readLink" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            // Create some targets
            const file_target_path = try ctx.transformPath("file.txt");
            try ctx.dir.writeFile(.{ .sub_path = file_target_path, .data = "nonsense" });
            const dir_target_path = try ctx.transformPath("subdir");
            try ctx.dir.makeDir(dir_target_path);

            // On Windows, symlink targets always use the canonical path separator
            const canonical_file_target_path = try ctx.toCanonicalPathSep(file_target_path);
            const canonical_dir_target_path = try ctx.toCanonicalPathSep(dir_target_path);

            // test 1: symlink to a file
            try setupSymlink(ctx.dir, file_target_path, "symlink1", .{});
            try testReadLink(ctx.dir, canonical_file_target_path, "symlink1");

            // test 2: symlink to a directory (can be different on Windows)
            try setupSymlink(ctx.dir, dir_target_path, "symlink2", .{ .is_directory = true });
            try testReadLink(ctx.dir, canonical_dir_target_path, "symlink2");

            // test 3: relative path symlink
            const parent_file = ".." ++ fs.path.sep_str ++ "target.txt";
            const canonical_parent_file = try ctx.toCanonicalPathSep(parent_file);
            var subdir = try ctx.dir.makeOpenPath("subdir", .{});
            defer subdir.close();
            try setupSymlink(subdir, canonical_parent_file, "relative-link.txt", .{});
            try testReadLink(subdir, canonical_parent_file, "relative-link.txt");
        }
    }.impl);
}

fn testReadLink(dir: Dir, target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.max_path_bytes]u8 = undefined;
    const actual = try dir.readLink(symlink_path, buffer[0..]);
    try testing.expectEqualStrings(target_path, actual);
}

fn testReadLinkAbsolute(target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.max_path_bytes]u8 = undefined;
    const given = try fs.readLinkAbsolute(symlink_path, buffer[0..]);
    try testing.expectEqualStrings(target_path, given);
}

test "File.stat on a File that is a symlink returns Kind.sym_link" {
    // This test requires getting a file descriptor of a symlink which
    // is not possible on all targets
    switch (builtin.target.os.tag) {
        .windows, .linux => {},
        else => return error.SkipZigTest,
    }

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const dir_target_path = try ctx.transformPath("subdir");
            try ctx.dir.makeDir(dir_target_path);

            try setupSymlink(ctx.dir, dir_target_path, "symlink", .{ .is_directory = true });

            var symlink = switch (builtin.target.os.tag) {
                .windows => windows_symlink: {
                    const sub_path_w = try windows.cStrToPrefixedFileW(ctx.dir.fd, "symlink");

                    var result = Dir{
                        .fd = undefined,
                    };

                    const path_len_bytes = @as(u16, @intCast(sub_path_w.span().len * 2));
                    var nt_name = windows.UNICODE_STRING{
                        .Length = path_len_bytes,
                        .MaximumLength = path_len_bytes,
                        .Buffer = @constCast(&sub_path_w.data),
                    };
                    var attr = windows.OBJECT_ATTRIBUTES{
                        .Length = @sizeOf(windows.OBJECT_ATTRIBUTES),
                        .RootDirectory = if (fs.path.isAbsoluteWindowsW(sub_path_w.span())) null else ctx.dir.fd,
                        .Attributes = 0,
                        .ObjectName = &nt_name,
                        .SecurityDescriptor = null,
                        .SecurityQualityOfService = null,
                    };
                    var io: windows.IO_STATUS_BLOCK = undefined;
                    const rc = windows.ntdll.NtCreateFile(
                        &result.fd,
                        windows.STANDARD_RIGHTS_READ | windows.FILE_READ_ATTRIBUTES | windows.FILE_READ_EA | windows.SYNCHRONIZE | windows.FILE_TRAVERSE,
                        &attr,
                        &io,
                        null,
                        windows.FILE_ATTRIBUTE_NORMAL,
                        windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE | windows.FILE_SHARE_DELETE,
                        windows.FILE_OPEN,
                        // FILE_OPEN_REPARSE_POINT is the important thing here
                        windows.FILE_OPEN_REPARSE_POINT | windows.FILE_DIRECTORY_FILE | windows.FILE_SYNCHRONOUS_IO_NONALERT | windows.FILE_OPEN_FOR_BACKUP_INTENT,
                        null,
                        0,
                    );

                    switch (rc) {
                        .SUCCESS => break :windows_symlink result,
                        else => return windows.unexpectedStatus(rc),
                    }
                },
                .linux => linux_symlink: {
                    const sub_path_c = try posix.toPosixPath("symlink");
                    // the O_NOFOLLOW | O_PATH combination can obtain a fd to a symlink
                    // note that if O_DIRECTORY is set, then this will error with ENOTDIR
                    const flags: posix.O = .{
                        .NOFOLLOW = true,
                        .PATH = true,
                        .ACCMODE = .RDONLY,
                        .CLOEXEC = true,
                    };
                    const fd = try posix.openatZ(ctx.dir.fd, &sub_path_c, flags, 0);
                    break :linux_symlink Dir{ .fd = fd };
                },
                else => unreachable,
            };
            defer symlink.close();

            const stat = try symlink.stat();
            try testing.expectEqual(File.Kind.sym_link, stat.kind);
        }
    }.impl);
}

test "openDir" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const allocator = ctx.arena.allocator();
            const subdir_path = try ctx.transformPath("subdir");
            try ctx.dir.makeDir(subdir_path);

            for ([_][]const u8{ "", ".", ".." }) |sub_path| {
                const dir_path = try fs.path.join(allocator, &.{ subdir_path, sub_path });
                var dir = try ctx.dir.openDir(dir_path, .{});
                defer dir.close();
            }
        }
    }.impl);
}

test "accessAbsolute" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    try fs.accessAbsolute(base_path, .{});
}

test "openDirAbsolute" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("subdir");
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..], "subdir" });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    {
        var dir = try fs.openDirAbsolute(base_path, .{});
        defer dir.close();
    }

    for ([_][]const u8{ ".", ".." }) |sub_path| {
        const dir_path = try fs.path.join(allocator, &.{ base_path, sub_path });
        var dir = try fs.openDirAbsolute(dir_path, .{});
        defer dir.close();
    }
}

test "openDir cwd parent '..'" {
    if (native_os == .wasi) return error.SkipZigTest;

    var dir = try fs.cwd().openDir("..", .{});
    defer dir.close();
}

test "openDir non-cwd parent '..'" {
    switch (native_os) {
        .wasi, .netbsd, .openbsd => return error.SkipZigTest,
        else => {},
    }

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var subdir = try tmp.dir.makeOpenPath("subdir", .{});
    defer subdir.close();

    var dir = try subdir.openDir("..", .{});
    defer dir.close();

    const expected_path = try tmp.dir.realpathAlloc(testing.allocator, ".");
    defer testing.allocator.free(expected_path);

    const actual_path = try dir.realpathAlloc(testing.allocator, ".");
    defer testing.allocator.free(actual_path);

    try testing.expectEqualStrings(expected_path, actual_path);
}

test "readLinkAbsolute" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Create some targets
    try tmp.dir.writeFile(.{ .sub_path = "file.txt", .data = "nonsense" });
    try tmp.dir.makeDir("subdir");

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    {
        const target_path = try fs.path.join(allocator, &.{ base_path, "file.txt" });
        const symlink_path = try fs.path.join(allocator, &.{ base_path, "symlink1" });

        // Create symbolic link by path
        try setupSymlinkAbsolute(target_path, symlink_path, .{});
        try testReadLinkAbsolute(target_path, symlink_path);
    }
    {
        const target_path = try fs.path.join(allocator, &.{ base_path, "subdir" });
        const symlink_path = try fs.path.join(allocator, &.{ base_path, "symlink2" });

        // Create symbolic link to a directory by path
        try setupSymlinkAbsolute(target_path, symlink_path, .{ .is_directory = true });
        try testReadLinkAbsolute(target_path, symlink_path);
    }
}

test "Dir.Iterator" {
    var tmp_dir = tmpDir(.{ .iterate = true });
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var entries = std.ArrayList(Dir.Entry).init(allocator);

    // Create iterator.
    var iter = tmp_dir.dir.iterate();
    while (try iter.next()) |entry| {
        // We cannot just store `entry` as on Windows, we're re-using the name buffer
        // which means we'll actually share the `name` pointer between entries!
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(Dir.Entry{ .name = name, .kind = entry.kind });
    }

    try testing.expectEqual(@as(usize, 2), entries.items.len); // note that the Iterator skips '.' and '..'
    try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .file }));
    try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .directory }));
}

test "Dir.Iterator many entries" {
    var tmp_dir = tmpDir(.{ .iterate = true });
    defer tmp_dir.cleanup();

    const num = 1024;
    var i: usize = 0;
    var buf: [4]u8 = undefined; // Enough to store "1024".
    while (i < num) : (i += 1) {
        const name = try std.fmt.bufPrint(&buf, "{}", .{i});
        const file = try tmp_dir.dir.createFile(name, .{});
        file.close();
    }

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var entries = std.ArrayList(Dir.Entry).init(allocator);

    // Create iterator.
    var iter = tmp_dir.dir.iterate();
    while (try iter.next()) |entry| {
        // We cannot just store `entry` as on Windows, we're re-using the name buffer
        // which means we'll actually share the `name` pointer between entries!
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(.{ .name = name, .kind = entry.kind });
    }

    i = 0;
    while (i < num) : (i += 1) {
        const name = try std.fmt.bufPrint(&buf, "{}", .{i});
        try testing.expect(contains(&entries, .{ .name = name, .kind = .file }));
    }
}

test "Dir.Iterator twice" {
    var tmp_dir = tmpDir(.{ .iterate = true });
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        var entries = std.ArrayList(Dir.Entry).init(allocator);

        // Create iterator.
        var iter = tmp_dir.dir.iterate();
        while (try iter.next()) |entry| {
            // We cannot just store `entry` as on Windows, we're re-using the name buffer
            // which means we'll actually share the `name` pointer between entries!
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(Dir.Entry{ .name = name, .kind = entry.kind });
        }

        try testing.expectEqual(@as(usize, 2), entries.items.len); // note that the Iterator skips '.' and '..'
        try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .file }));
        try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .directory }));
    }
}

test "Dir.Iterator reset" {
    var tmp_dir = tmpDir(.{ .iterate = true });
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create iterator.
    var iter = tmp_dir.dir.iterate();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        var entries = std.ArrayList(Dir.Entry).init(allocator);

        while (try iter.next()) |entry| {
            // We cannot just store `entry` as on Windows, we're re-using the name buffer
            // which means we'll actually share the `name` pointer between entries!
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(.{ .name = name, .kind = entry.kind });
        }

        try testing.expectEqual(@as(usize, 2), entries.items.len); // note that the Iterator skips '.' and '..'
        try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .file }));
        try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .directory }));

        iter.reset();
    }
}

test "Dir.Iterator but dir is deleted during iteration" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create directory and setup an iterator for it
    var subdir = try tmp.dir.makeOpenPath("subdir", .{ .iterate = true });
    defer subdir.close();

    var iterator = subdir.iterate();

    // Create something to iterate over within the subdir
    try tmp.dir.makePath("subdir" ++ fs.path.sep_str ++ "b");

    // Then, before iterating, delete the directory that we're iterating.
    // This is a contrived reproduction, but this could happen outside of the program, in another thread, etc.
    // If we get an error while trying to delete, we can skip this test (this will happen on platforms
    // like Windows which will give FileBusy if the directory is currently open for iteration).
    tmp.dir.deleteTree("subdir") catch return error.SkipZigTest;

    // Now, when we try to iterate, the next call should return null immediately.
    const entry = try iterator.next();
    try std.testing.expect(entry == null);

    // On Linux, we can opt-in to receiving a more specific error by calling `nextLinux`
    if (native_os == .linux) {
        try std.testing.expectError(error.DirNotFound, iterator.nextLinux());
    }
}

fn entryEql(lhs: Dir.Entry, rhs: Dir.Entry) bool {
    return mem.eql(u8, lhs.name, rhs.name) and lhs.kind == rhs.kind;
}

fn contains(entries: *const std.ArrayList(Dir.Entry), el: Dir.Entry) bool {
    for (entries.items) |entry| {
        if (entryEql(entry, el)) return true;
    }
    return false;
}

test "Dir.realpath smoke test" {
    if (!comptime std.os.isGetFdPathSupportedOnTarget(builtin.os)) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const allocator = ctx.arena.allocator();
            const test_file_path = try ctx.transformPath("test_file");
            const test_dir_path = try ctx.transformPath("test_dir");
            var buf: [fs.max_path_bytes]u8 = undefined;

            // FileNotFound if the path doesn't exist
            try testing.expectError(error.FileNotFound, ctx.dir.realpathAlloc(allocator, test_file_path));
            try testing.expectError(error.FileNotFound, ctx.dir.realpath(test_file_path, &buf));
            try testing.expectError(error.FileNotFound, ctx.dir.realpathAlloc(allocator, test_dir_path));
            try testing.expectError(error.FileNotFound, ctx.dir.realpath(test_dir_path, &buf));

            // Now create the file and dir
            try ctx.dir.writeFile(.{ .sub_path = test_file_path, .data = "" });
            try ctx.dir.makeDir(test_dir_path);

            const base_path = try ctx.transformPath(".");
            const base_realpath = try ctx.dir.realpathAlloc(allocator, base_path);
            const expected_file_path = try fs.path.join(
                allocator,
                &.{ base_realpath, "test_file" },
            );
            const expected_dir_path = try fs.path.join(
                allocator,
                &.{ base_realpath, "test_dir" },
            );

            // First, test non-alloc version
            {
                const file_path = try ctx.dir.realpath(test_file_path, &buf);
                try testing.expectEqualStrings(expected_file_path, file_path);

                const dir_path = try ctx.dir.realpath(test_dir_path, &buf);
                try testing.expectEqualStrings(expected_dir_path, dir_path);
            }

            // Next, test alloc version
            {
                const file_path = try ctx.dir.realpathAlloc(allocator, test_file_path);
                try testing.expectEqualStrings(expected_file_path, file_path);

                const dir_path = try ctx.dir.realpathAlloc(allocator, test_dir_path);
                try testing.expectEqualStrings(expected_dir_path, dir_path);
            }
        }
    }.impl);
}

test "readAllAlloc" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var file = try tmp_dir.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const buf1 = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(buf1);
    try testing.expectEqual(@as(usize, 0), buf1.len);

    const write_buf: []const u8 = "this is a test.\nthis is a test.\nthis is a test.\nthis is a test.\n";
    try file.writeAll(write_buf);
    try file.seekTo(0);

    // max_bytes > file_size
    const buf2 = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(buf2);
    try testing.expectEqual(write_buf.len, buf2.len);
    try testing.expectEqualStrings(write_buf, buf2);
    try file.seekTo(0);

    // max_bytes == file_size
    const buf3 = try file.readToEndAlloc(testing.allocator, write_buf.len);
    defer testing.allocator.free(buf3);
    try testing.expectEqual(write_buf.len, buf3.len);
    try testing.expectEqualStrings(write_buf, buf3);
    try file.seekTo(0);

    // max_bytes < file_size
    try testing.expectError(error.FileTooBig, file.readToEndAlloc(testing.allocator, write_buf.len - 1));
}

test "Dir.statFile" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_file_name = try ctx.transformPath("test_file");

            try testing.expectError(error.FileNotFound, ctx.dir.statFile(test_file_name));

            try ctx.dir.writeFile(.{ .sub_path = test_file_name, .data = "" });

            const stat = try ctx.dir.statFile(test_file_name);
            try testing.expectEqual(File.Kind.file, stat.kind);
        }
    }.impl);
}

test "statFile on dangling symlink" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const symlink_name = try ctx.transformPath("dangling-symlink");
            const symlink_target = "." ++ fs.path.sep_str ++ "doesnotexist";

            try setupSymlink(ctx.dir, symlink_target, symlink_name, .{});

            try std.testing.expectError(error.FileNotFound, ctx.dir.statFile(symlink_name));
        }
    }.impl);
}

test "directory operations on files" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_file_name = try ctx.transformPath("test_file");

            var file = try ctx.dir.createFile(test_file_name, .{ .read = true });
            file.close();

            try testing.expectError(error.PathAlreadyExists, ctx.dir.makeDir(test_file_name));
            try testing.expectError(error.NotDir, ctx.dir.openDir(test_file_name, .{}));
            try testing.expectError(error.NotDir, ctx.dir.deleteDir(test_file_name));

            if (ctx.path_type == .absolute and comptime PathType.absolute.isSupported(builtin.os)) {
                try testing.expectError(error.PathAlreadyExists, fs.makeDirAbsolute(test_file_name));
                try testing.expectError(error.NotDir, fs.deleteDirAbsolute(test_file_name));
            }

            // ensure the file still exists and is a file as a sanity check
            file = try ctx.dir.openFile(test_file_name, .{});
            const stat = try file.stat();
            try testing.expectEqual(File.Kind.file, stat.kind);
            file.close();
        }
    }.impl);
}

test "file operations on directories" {
    // TODO: fix this test on FreeBSD. https://github.com/ziglang/zig/issues/1759
    if (native_os == .freebsd) return error.SkipZigTest;
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/20747

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_dir_name = try ctx.transformPath("test_dir");

            try ctx.dir.makeDir(test_dir_name);

            try testing.expectError(error.IsDir, ctx.dir.createFile(test_dir_name, .{}));
            try testing.expectError(error.IsDir, ctx.dir.deleteFile(test_dir_name));
            switch (native_os) {
                // no error when reading a directory.
                .dragonfly, .netbsd => {},
                // Currently, WASI will return error.Unexpected (via ENOTCAPABLE) when attempting fd_read on a directory handle.
                // TODO: Re-enable on WASI once https://github.com/bytecodealliance/wasmtime/issues/1935 is resolved.
                .wasi => {},
                else => {
                    try testing.expectError(error.IsDir, ctx.dir.readFileAlloc(testing.allocator, test_dir_name, std.math.maxInt(usize)));
                },
            }
            // Note: The `.mode = .read_write` is necessary to ensure the error occurs on all platforms.
            // TODO: Add a read-only test as well, see https://github.com/ziglang/zig/issues/5732
            try testing.expectError(error.IsDir, ctx.dir.openFile(test_dir_name, .{ .mode = .read_write }));

            if (ctx.path_type == .absolute and comptime PathType.absolute.isSupported(builtin.os)) {
                try testing.expectError(error.IsDir, fs.createFileAbsolute(test_dir_name, .{}));
                try testing.expectError(error.IsDir, fs.deleteFileAbsolute(test_dir_name));
            }

            // ensure the directory still exists as a sanity check
            var dir = try ctx.dir.openDir(test_dir_name, .{});
            dir.close();
        }
    }.impl);
}

test "makeOpenPath parent dirs do not exist" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var dir = try tmp_dir.dir.makeOpenPath("root_dir/parent_dir/some_dir", .{});
    dir.close();

    // double check that the full directory structure was created
    var dir_verification = try tmp_dir.dir.openDir("root_dir/parent_dir/some_dir", .{});
    dir_verification.close();
}

test "deleteDir" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_dir_path = try ctx.transformPath("test_dir");
            const test_file_path = try ctx.transformPath("test_dir" ++ fs.path.sep_str ++ "test_file");

            // deleting a non-existent directory
            try testing.expectError(error.FileNotFound, ctx.dir.deleteDir(test_dir_path));

            // deleting a non-empty directory
            try ctx.dir.makeDir(test_dir_path);
            try ctx.dir.writeFile(.{ .sub_path = test_file_path, .data = "" });
            try testing.expectError(error.DirNotEmpty, ctx.dir.deleteDir(test_dir_path));

            // deleting an empty directory
            try ctx.dir.deleteFile(test_file_path);
            try ctx.dir.deleteDir(test_dir_path);
        }
    }.impl);
}

test "Dir.rename files" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            // Rename on Windows can hit intermittent AccessDenied errors
            // when certain conditions are true about the host system.
            // For now, skip this test when the path type is UNC to avoid them.
            // See https://github.com/ziglang/zig/issues/17134
            if (ctx.path_type == .unc) return;

            const missing_file_path = try ctx.transformPath("missing_file_name");
            const something_else_path = try ctx.transformPath("something_else");

            try testing.expectError(error.FileNotFound, ctx.dir.rename(missing_file_path, something_else_path));

            // Renaming files
            const test_file_name = try ctx.transformPath("test_file");
            const renamed_test_file_name = try ctx.transformPath("test_file_renamed");
            var file = try ctx.dir.createFile(test_file_name, .{ .read = true });
            file.close();
            try ctx.dir.rename(test_file_name, renamed_test_file_name);

            // Ensure the file was renamed
            try testing.expectError(error.FileNotFound, ctx.dir.openFile(test_file_name, .{}));
            file = try ctx.dir.openFile(renamed_test_file_name, .{});
            file.close();

            // Rename to self succeeds
            try ctx.dir.rename(renamed_test_file_name, renamed_test_file_name);

            // Rename to existing file succeeds
            const existing_file_path = try ctx.transformPath("existing_file");
            var existing_file = try ctx.dir.createFile(existing_file_path, .{ .read = true });
            existing_file.close();
            try ctx.dir.rename(renamed_test_file_name, existing_file_path);

            try testing.expectError(error.FileNotFound, ctx.dir.openFile(renamed_test_file_name, .{}));
            file = try ctx.dir.openFile(existing_file_path, .{});
            file.close();
        }
    }.impl);
}

test "Dir.rename directories" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            // Rename on Windows can hit intermittent AccessDenied errors
            // when certain conditions are true about the host system.
            // For now, skip this test when the path type is UNC to avoid them.
            // See https://github.com/ziglang/zig/issues/17134
            if (ctx.path_type == .unc) return;

            const test_dir_path = try ctx.transformPath("test_dir");
            const test_dir_renamed_path = try ctx.transformPath("test_dir_renamed");

            // Renaming directories
            try ctx.dir.makeDir(test_dir_path);
            try ctx.dir.rename(test_dir_path, test_dir_renamed_path);

            // Ensure the directory was renamed
            try testing.expectError(error.FileNotFound, ctx.dir.openDir(test_dir_path, .{}));
            var dir = try ctx.dir.openDir(test_dir_renamed_path, .{});

            // Put a file in the directory
            var file = try dir.createFile("test_file", .{ .read = true });
            file.close();
            dir.close();

            const test_dir_renamed_again_path = try ctx.transformPath("test_dir_renamed_again");
            try ctx.dir.rename(test_dir_renamed_path, test_dir_renamed_again_path);

            // Ensure the directory was renamed and the file still exists in it
            try testing.expectError(error.FileNotFound, ctx.dir.openDir(test_dir_renamed_path, .{}));
            dir = try ctx.dir.openDir(test_dir_renamed_again_path, .{});
            file = try dir.openFile("test_file", .{});
            file.close();
            dir.close();
        }
    }.impl);
}

test "Dir.rename directory onto empty dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (native_os == .windows) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_dir_path = try ctx.transformPath("test_dir");
            const target_dir_path = try ctx.transformPath("target_dir_path");

            try ctx.dir.makeDir(test_dir_path);
            try ctx.dir.makeDir(target_dir_path);
            try ctx.dir.rename(test_dir_path, target_dir_path);

            // Ensure the directory was renamed
            try testing.expectError(error.FileNotFound, ctx.dir.openDir(test_dir_path, .{}));
            var dir = try ctx.dir.openDir(target_dir_path, .{});
            dir.close();
        }
    }.impl);
}

test "Dir.rename directory onto non-empty dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (native_os == .windows) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_dir_path = try ctx.transformPath("test_dir");
            const target_dir_path = try ctx.transformPath("target_dir_path");

            try ctx.dir.makeDir(test_dir_path);

            var target_dir = try ctx.dir.makeOpenPath(target_dir_path, .{});
            var file = try target_dir.createFile("test_file", .{ .read = true });
            file.close();
            target_dir.close();

            // Rename should fail with PathAlreadyExists if target_dir is non-empty
            try testing.expectError(error.PathAlreadyExists, ctx.dir.rename(test_dir_path, target_dir_path));

            // Ensure the directory was not renamed
            var dir = try ctx.dir.openDir(test_dir_path, .{});
            dir.close();
        }
    }.impl);
}

test "Dir.rename file <-> dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (native_os == .windows) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const test_file_path = try ctx.transformPath("test_file");
            const test_dir_path = try ctx.transformPath("test_dir");

            var file = try ctx.dir.createFile(test_file_path, .{ .read = true });
            file.close();
            try ctx.dir.makeDir(test_dir_path);
            try testing.expectError(error.IsDir, ctx.dir.rename(test_file_path, test_dir_path));
            try testing.expectError(error.NotDir, ctx.dir.rename(test_dir_path, test_file_path));
        }
    }.impl);
}

test "rename" {
    var tmp_dir1 = tmpDir(.{});
    defer tmp_dir1.cleanup();

    var tmp_dir2 = tmpDir(.{});
    defer tmp_dir2.cleanup();

    // Renaming files
    const test_file_name = "test_file";
    const renamed_test_file_name = "test_file_renamed";
    var file = try tmp_dir1.dir.createFile(test_file_name, .{ .read = true });
    file.close();
    try fs.rename(tmp_dir1.dir, test_file_name, tmp_dir2.dir, renamed_test_file_name);

    // ensure the file was renamed
    try testing.expectError(error.FileNotFound, tmp_dir1.dir.openFile(test_file_name, .{}));
    file = try tmp_dir2.dir.openFile(renamed_test_file_name, .{});
    file.close();
}

test "renameAbsolute" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &.{ ".zig-cache", "tmp", tmp_dir.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    try testing.expectError(error.FileNotFound, fs.renameAbsolute(
        try fs.path.join(allocator, &.{ base_path, "missing_file_name" }),
        try fs.path.join(allocator, &.{ base_path, "something_else" }),
    ));

    // Renaming files
    const test_file_name = "test_file";
    const renamed_test_file_name = "test_file_renamed";
    var file = try tmp_dir.dir.createFile(test_file_name, .{ .read = true });
    file.close();
    try fs.renameAbsolute(
        try fs.path.join(allocator, &.{ base_path, test_file_name }),
        try fs.path.join(allocator, &.{ base_path, renamed_test_file_name }),
    );

    // ensure the file was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openFile(test_file_name, .{}));
    file = try tmp_dir.dir.openFile(renamed_test_file_name, .{});
    const stat = try file.stat();
    try testing.expectEqual(File.Kind.file, stat.kind);
    file.close();

    // Renaming directories
    const test_dir_name = "test_dir";
    const renamed_test_dir_name = "test_dir_renamed";
    try tmp_dir.dir.makeDir(test_dir_name);
    try fs.renameAbsolute(
        try fs.path.join(allocator, &.{ base_path, test_dir_name }),
        try fs.path.join(allocator, &.{ base_path, renamed_test_dir_name }),
    );

    // ensure the directory was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openDir(test_dir_name, .{}));
    var dir = try tmp_dir.dir.openDir(renamed_test_dir_name, .{});
    dir.close();
}

test "openSelfExe" {
    if (native_os == .wasi) return error.SkipZigTest;

    const self_exe_file = try std.fs.openSelfExe(.{});
    self_exe_file.close();
}

test "selfExePath" {
    if (native_os == .wasi) return error.SkipZigTest;

    var buf: [fs.max_path_bytes]u8 = undefined;
    const buf_self_exe_path = try std.fs.selfExePath(&buf);
    const alloc_self_exe_path = try std.fs.selfExePathAlloc(testing.allocator);
    defer testing.allocator.free(alloc_self_exe_path);
    try testing.expectEqualSlices(u8, buf_self_exe_path, alloc_self_exe_path);
}

test "deleteTree does not follow symlinks" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("b");
    {
        var a = try tmp.dir.makeOpenPath("a", .{});
        defer a.close();

        try setupSymlink(a, "../b", "b", .{ .is_directory = true });
    }

    try tmp.dir.deleteTree("a");

    try testing.expectError(error.FileNotFound, tmp.dir.access("a", .{}));
    try tmp.dir.access("b", .{});
}

test "deleteTree on a symlink" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Symlink to a file
    try tmp.dir.writeFile(.{ .sub_path = "file", .data = "" });
    try setupSymlink(tmp.dir, "file", "filelink", .{});

    try tmp.dir.deleteTree("filelink");
    try testing.expectError(error.FileNotFound, tmp.dir.access("filelink", .{}));
    try tmp.dir.access("file", .{});

    // Symlink to a directory
    try tmp.dir.makePath("dir");
    try setupSymlink(tmp.dir, "dir", "dirlink", .{ .is_directory = true });

    try tmp.dir.deleteTree("dirlink");
    try testing.expectError(error.FileNotFound, tmp.dir.access("dirlink", .{}));
    try tmp.dir.access("dir", .{});
}

test "makePath, put some files in it, deleteTree" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const allocator = ctx.arena.allocator();
            const dir_path = try ctx.transformPath("os_test_tmp");

            try ctx.dir.makePath(try fs.path.join(allocator, &.{ "os_test_tmp", "b", "c" }));
            try ctx.dir.writeFile(.{
                .sub_path = try fs.path.join(allocator, &.{ "os_test_tmp", "b", "c", "file.txt" }),
                .data = "nonsense",
            });
            try ctx.dir.writeFile(.{
                .sub_path = try fs.path.join(allocator, &.{ "os_test_tmp", "b", "file2.txt" }),
                .data = "blah",
            });

            try ctx.dir.deleteTree(dir_path);
            try testing.expectError(error.FileNotFound, ctx.dir.openDir(dir_path, .{}));
        }
    }.impl);
}

test "makePath, put some files in it, deleteTreeMinStackSize" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const allocator = ctx.arena.allocator();
            const dir_path = try ctx.transformPath("os_test_tmp");

            try ctx.dir.makePath(try fs.path.join(allocator, &.{ "os_test_tmp", "b", "c" }));
            try ctx.dir.writeFile(.{
                .sub_path = try fs.path.join(allocator, &.{ "os_test_tmp", "b", "c", "file.txt" }),
                .data = "nonsense",
            });
            try ctx.dir.writeFile(.{
                .sub_path = try fs.path.join(allocator, &.{ "os_test_tmp", "b", "file2.txt" }),
                .data = "blah",
            });

            try ctx.dir.deleteTreeMinStackSize(dir_path);
            try testing.expectError(error.FileNotFound, ctx.dir.openDir(dir_path, .{}));
        }
    }.impl);
}

test "makePath in a directory that no longer exists" {
    if (native_os == .windows) return error.SkipZigTest; // Windows returns FileBusy if attempting to remove an open dir

    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    try tmp.parent_dir.deleteTree(&tmp.sub_path);

    try testing.expectError(error.FileNotFound, tmp.dir.makePath("sub-path"));
}

test "makePath but sub_path contains pre-existing file" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("foo");
    try tmp.dir.writeFile(.{ .sub_path = "foo/bar", .data = "" });

    try testing.expectError(error.NotDir, tmp.dir.makePath("foo/bar/baz"));
}

fn expectDir(dir: Dir, path: []const u8) !void {
    var d = try dir.openDir(path, .{});
    d.close();
}

test "makepath existing directories" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("A");
    var tmpA = try tmp.dir.openDir("A", .{});
    defer tmpA.close();
    try tmpA.makeDir("B");

    const testPath = "A" ++ fs.path.sep_str ++ "B" ++ fs.path.sep_str ++ "C";
    try tmp.dir.makePath(testPath);

    try expectDir(tmp.dir, testPath);
}

test "makepath through existing valid symlink" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("realfolder");
    try setupSymlink(tmp.dir, "." ++ fs.path.sep_str ++ "realfolder", "working-symlink", .{});

    try tmp.dir.makePath("working-symlink" ++ fs.path.sep_str ++ "in-realfolder");

    try expectDir(tmp.dir, "realfolder" ++ fs.path.sep_str ++ "in-realfolder");
}

test "makepath relative walks" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const relPath = try fs.path.join(testing.allocator, &.{
        "first", "..", "second", "..", "third", "..", "first", "A", "..", "B", "..", "C",
    });
    defer testing.allocator.free(relPath);

    try tmp.dir.makePath(relPath);

    // How .. is handled is different on Windows than non-Windows
    switch (native_os) {
        .windows => {
            // On Windows, .. is resolved before passing the path to NtCreateFile,
            // meaning everything except `first/C` drops out.
            try expectDir(tmp.dir, "first" ++ fs.path.sep_str ++ "C");
            try testing.expectError(error.FileNotFound, tmp.dir.access("second", .{}));
            try testing.expectError(error.FileNotFound, tmp.dir.access("third", .{}));
        },
        else => {
            try expectDir(tmp.dir, "first" ++ fs.path.sep_str ++ "A");
            try expectDir(tmp.dir, "first" ++ fs.path.sep_str ++ "B");
            try expectDir(tmp.dir, "first" ++ fs.path.sep_str ++ "C");
            try expectDir(tmp.dir, "second");
            try expectDir(tmp.dir, "third");
        },
    }
}

test "makepath ignores '.'" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Path to create, with "." elements:
    const dotPath = try fs.path.join(testing.allocator, &.{
        "first", ".", "second", ".", "third",
    });
    defer testing.allocator.free(dotPath);

    // Path to expect to find:
    const expectedPath = try fs.path.join(testing.allocator, &.{
        "first", "second", "third",
    });
    defer testing.allocator.free(expectedPath);

    try tmp.dir.makePath(dotPath);

    try expectDir(tmp.dir, expectedPath);
}

fn testFilenameLimits(iterable_dir: Dir, maxed_filename: []const u8) !void {
    // setup, create a dir and a nested file both with maxed filenames, and walk the dir
    {
        var maxed_dir = try iterable_dir.makeOpenPath(maxed_filename, .{});
        defer maxed_dir.close();

        try maxed_dir.writeFile(.{ .sub_path = maxed_filename, .data = "" });

        var walker = try iterable_dir.walk(testing.allocator);
        defer walker.deinit();

        var count: usize = 0;
        while (try walker.next()) |entry| {
            try testing.expectEqualStrings(maxed_filename, entry.basename);
            count += 1;
        }
        try testing.expectEqual(@as(usize, 2), count);
    }

    // ensure that we can delete the tree
    try iterable_dir.deleteTree(maxed_filename);
}

test "max file name component lengths" {
    var tmp = tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    if (native_os == .windows) {
        // U+FFFF is the character with the largest code point that is encoded as a single
        // UTF-16 code unit, so Windows allows for NAME_MAX of them.
        const maxed_windows_filename = ("\u{FFFF}".*) ** windows.NAME_MAX;
        try testFilenameLimits(tmp.dir, &maxed_windows_filename);
    } else if (native_os == .wasi) {
        // On WASI, the maxed filename depends on the host OS, so in order for this test to
        // work on any host, we need to use a length that will work for all platforms
        // (i.e. the minimum max_name_bytes of all supported platforms).
        const maxed_wasi_filename = [_]u8{'1'} ** 255;
        try testFilenameLimits(tmp.dir, &maxed_wasi_filename);
    } else {
        const maxed_ascii_filename = [_]u8{'1'} ** std.fs.max_name_bytes;
        try testFilenameLimits(tmp.dir, &maxed_ascii_filename);
    }
}

test "writev, readv" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const line1 = "line1\n";
    const line2 = "line2\n";

    var buf1: [line1.len]u8 = undefined;
    var buf2: [line2.len]u8 = undefined;
    var write_vecs = [_]posix.iovec_const{
        .{
            .base = line1,
            .len = line1.len,
        },
        .{
            .base = line2,
            .len = line2.len,
        },
    };
    var read_vecs = [_]posix.iovec{
        .{
            .base = &buf2,
            .len = buf2.len,
        },
        .{
            .base = &buf1,
            .len = buf1.len,
        },
    };

    var src_file = try tmp.dir.createFile("test.txt", .{ .read = true });
    defer src_file.close();

    try src_file.writevAll(&write_vecs);
    try testing.expectEqual(@as(u64, line1.len + line2.len), try src_file.getEndPos());
    try src_file.seekTo(0);
    const read = try src_file.readvAll(&read_vecs);
    try testing.expectEqual(@as(usize, line1.len + line2.len), read);
    try testing.expectEqualStrings(&buf1, "line2\n");
    try testing.expectEqualStrings(&buf2, "line1\n");
}

test "pwritev, preadv" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const line1 = "line1\n";
    const line2 = "line2\n";

    var buf1: [line1.len]u8 = undefined;
    var buf2: [line2.len]u8 = undefined;
    var write_vecs = [_]posix.iovec_const{
        .{
            .base = line1,
            .len = line1.len,
        },
        .{
            .base = line2,
            .len = line2.len,
        },
    };
    var read_vecs = [_]posix.iovec{
        .{
            .base = &buf2,
            .len = buf2.len,
        },
        .{
            .base = &buf1,
            .len = buf1.len,
        },
    };

    var src_file = try tmp.dir.createFile("test.txt", .{ .read = true });
    defer src_file.close();

    try src_file.pwritevAll(&write_vecs, 16);
    try testing.expectEqual(@as(u64, 16 + line1.len + line2.len), try src_file.getEndPos());
    const read = try src_file.preadvAll(&read_vecs, 16);
    try testing.expectEqual(@as(usize, line1.len + line2.len), read);
    try testing.expectEqualStrings(&buf1, "line2\n");
    try testing.expectEqualStrings(&buf2, "line1\n");
}

test "access file" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const dir_path = try ctx.transformPath("os_test_tmp");
            const file_path = try ctx.transformPath("os_test_tmp" ++ fs.path.sep_str ++ "file.txt");

            try ctx.dir.makePath(dir_path);
            try testing.expectError(error.FileNotFound, ctx.dir.access(file_path, .{}));

            try ctx.dir.writeFile(.{ .sub_path = file_path, .data = "" });
            try ctx.dir.access(file_path, .{});
            try ctx.dir.deleteTree(dir_path);
        }
    }.impl);
}

test "sendfile" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    defer tmp.dir.deleteTree("os_test_tmp") catch {};

    var dir = try tmp.dir.openDir("os_test_tmp", .{});
    defer dir.close();

    const line1 = "line1\n";
    const line2 = "second line\n";
    var vecs = [_]posix.iovec_const{
        .{
            .base = line1,
            .len = line1.len,
        },
        .{
            .base = line2,
            .len = line2.len,
        },
    };

    var src_file = try dir.createFile("sendfile1.txt", .{ .read = true });
    defer src_file.close();

    try src_file.writevAll(&vecs);

    var dest_file = try dir.createFile("sendfile2.txt", .{ .read = true });
    defer dest_file.close();

    const header1 = "header1\n";
    const header2 = "second header\n";
    const trailer1 = "trailer1\n";
    const trailer2 = "second trailer\n";
    var hdtr = [_]posix.iovec_const{
        .{
            .base = header1,
            .len = header1.len,
        },
        .{
            .base = header2,
            .len = header2.len,
        },
        .{
            .base = trailer1,
            .len = trailer1.len,
        },
        .{
            .base = trailer2,
            .len = trailer2.len,
        },
    };

    var written_buf: [100]u8 = undefined;
    try dest_file.writeFileAll(src_file, .{
        .in_offset = 1,
        .in_len = 10,
        .headers_and_trailers = &hdtr,
        .header_count = 2,
    });
    const amt = try dest_file.preadAll(&written_buf, 0);
    try testing.expectEqualStrings("header1\nsecond header\nine1\nsecontrailer1\nsecond trailer\n", written_buf[0..amt]);
}

test "copyRangeAll" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    defer tmp.dir.deleteTree("os_test_tmp") catch {};

    var dir = try tmp.dir.openDir("os_test_tmp", .{});
    defer dir.close();

    var src_file = try dir.createFile("file1.txt", .{ .read = true });
    defer src_file.close();

    const data = "u6wj+JmdF3qHsFPE BUlH2g4gJCmEz0PP";
    try src_file.writeAll(data);

    var dest_file = try dir.createFile("file2.txt", .{ .read = true });
    defer dest_file.close();

    var written_buf: [100]u8 = undefined;
    _ = try src_file.copyRangeAll(0, dest_file, 0, data.len);

    const amt = try dest_file.preadAll(&written_buf, 0);
    try testing.expectEqualStrings(data, written_buf[0..amt]);
}

test "copyFile" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const data = "u6wj+JmdF3qHsFPE BUlH2g4gJCmEz0PP";
            const src_file = try ctx.transformPath("tmp_test_copy_file.txt");
            const dest_file = try ctx.transformPath("tmp_test_copy_file2.txt");
            const dest_file2 = try ctx.transformPath("tmp_test_copy_file3.txt");

            try ctx.dir.writeFile(.{ .sub_path = src_file, .data = data });
            defer ctx.dir.deleteFile(src_file) catch {};

            try ctx.dir.copyFile(src_file, ctx.dir, dest_file, .{});
            defer ctx.dir.deleteFile(dest_file) catch {};

            try ctx.dir.copyFile(src_file, ctx.dir, dest_file2, .{ .override_mode = File.default_mode });
            defer ctx.dir.deleteFile(dest_file2) catch {};

            try expectFileContents(ctx.dir, dest_file, data);
            try expectFileContents(ctx.dir, dest_file2, data);
        }
    }.impl);
}

fn expectFileContents(dir: Dir, file_path: []const u8, data: []const u8) !void {
    const contents = try dir.readFileAlloc(testing.allocator, file_path, 1000);
    defer testing.allocator.free(contents);

    try testing.expectEqualSlices(u8, data, contents);
}

test "AtomicFile" {
    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const allocator = ctx.arena.allocator();
            const test_out_file = try ctx.transformPath("tmp_atomic_file_test_dest.txt");
            const test_content =
                \\ hello!
                \\ this is a test file
            ;

            {
                var af = try ctx.dir.atomicFile(test_out_file, .{});
                defer af.deinit();
                try af.file.writeAll(test_content);
                try af.finish();
            }
            const content = try ctx.dir.readFileAlloc(allocator, test_out_file, 9999);
            try testing.expectEqualStrings(test_content, content);

            try ctx.dir.deleteFile(test_out_file);
        }
    }.impl);
}

test "open file with exclusive nonblocking lock twice" {
    if (native_os == .wasi) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const filename = try ctx.transformPath("file_nonblocking_lock_test.txt");

            const file1 = try ctx.dir.createFile(filename, .{ .lock = .exclusive, .lock_nonblocking = true });
            defer file1.close();

            const file2 = ctx.dir.createFile(filename, .{ .lock = .exclusive, .lock_nonblocking = true });
            try testing.expectError(error.WouldBlock, file2);
        }
    }.impl);
}

test "open file with shared and exclusive nonblocking lock" {
    if (native_os == .wasi) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const filename = try ctx.transformPath("file_nonblocking_lock_test.txt");

            const file1 = try ctx.dir.createFile(filename, .{ .lock = .shared, .lock_nonblocking = true });
            defer file1.close();

            const file2 = ctx.dir.createFile(filename, .{ .lock = .exclusive, .lock_nonblocking = true });
            try testing.expectError(error.WouldBlock, file2);
        }
    }.impl);
}

test "open file with exclusive and shared nonblocking lock" {
    if (native_os == .wasi) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const filename = try ctx.transformPath("file_nonblocking_lock_test.txt");

            const file1 = try ctx.dir.createFile(filename, .{ .lock = .exclusive, .lock_nonblocking = true });
            defer file1.close();

            const file2 = ctx.dir.createFile(filename, .{ .lock = .shared, .lock_nonblocking = true });
            try testing.expectError(error.WouldBlock, file2);
        }
    }.impl);
}

test "open file with exclusive lock twice, make sure second lock waits" {
    if (builtin.single_threaded) return error.SkipZigTest;

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const filename = try ctx.transformPath("file_lock_test.txt");

            const file = try ctx.dir.createFile(filename, .{ .lock = .exclusive });
            errdefer file.close();

            const S = struct {
                fn checkFn(dir: *fs.Dir, path: []const u8, started: *std.Thread.ResetEvent, locked: *std.Thread.ResetEvent) !void {
                    started.set();
                    const file1 = try dir.createFile(path, .{ .lock = .exclusive });

                    locked.set();
                    file1.close();
                }
            };

            var started = std.Thread.ResetEvent{};
            var locked = std.Thread.ResetEvent{};

            const t = try std.Thread.spawn(.{}, S.checkFn, .{
                &ctx.dir,
                filename,
                &started,
                &locked,
            });
            defer t.join();

            // Wait for the spawned thread to start trying to acquire the exclusive file lock.
            // Then wait a bit to make sure that can't acquire it since we currently hold the file lock.
            started.wait();
            try testing.expectError(error.Timeout, locked.timedWait(10 * std.time.ns_per_ms));

            // Release the file lock which should unlock the thread to lock it and set the locked event.
            file.close();
            locked.wait();
        }
    }.impl);
}

test "open file with exclusive nonblocking lock twice (absolute paths)" {
    if (native_os == .wasi) return error.SkipZigTest;

    var random_bytes: [12]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    var random_b64: [fs.base64_encoder.calcSize(random_bytes.len)]u8 = undefined;
    _ = fs.base64_encoder.encode(&random_b64, &random_bytes);

    const sub_path = random_b64 ++ "-zig-test-absolute-paths.txt";

    const gpa = testing.allocator;

    const cwd = try std.process.getCwdAlloc(gpa);
    defer gpa.free(cwd);

    const filename = try fs.path.resolve(gpa, &.{ cwd, sub_path });
    defer gpa.free(filename);

    defer fs.deleteFileAbsolute(filename) catch {}; // createFileAbsolute can leave files on failures
    const file1 = try fs.createFileAbsolute(filename, .{
        .lock = .exclusive,
        .lock_nonblocking = true,
    });

    const file2 = fs.createFileAbsolute(filename, .{
        .lock = .exclusive,
        .lock_nonblocking = true,
    });
    file1.close();
    try testing.expectError(error.WouldBlock, file2);
}

test "walker" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    var tmp = tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    // iteration order of walker is undefined, so need lookup maps to check against

    const expected_paths = std.StaticStringMap(void).initComptime(.{
        .{"dir1"},
        .{"dir2"},
        .{"dir3"},
        .{"dir4"},
        .{"dir3" ++ fs.path.sep_str ++ "sub1"},
        .{"dir3" ++ fs.path.sep_str ++ "sub2"},
        .{"dir3" ++ fs.path.sep_str ++ "sub2" ++ fs.path.sep_str ++ "subsub1"},
    });

    const expected_basenames = std.StaticStringMap(void).initComptime(.{
        .{"dir1"},
        .{"dir2"},
        .{"dir3"},
        .{"dir4"},
        .{"sub1"},
        .{"sub2"},
        .{"subsub1"},
    });

    for (expected_paths.keys()) |key| {
        try tmp.dir.makePath(key);
    }

    var walker = try tmp.dir.walk(testing.allocator);
    defer walker.deinit();

    var num_walked: usize = 0;
    while (try walker.next()) |entry| {
        testing.expect(expected_basenames.has(entry.basename)) catch |err| {
            std.debug.print("found unexpected basename: {s}\n", .{std.fmt.fmtSliceEscapeLower(entry.basename)});
            return err;
        };
        testing.expect(expected_paths.has(entry.path)) catch |err| {
            std.debug.print("found unexpected path: {s}\n", .{std.fmt.fmtSliceEscapeLower(entry.path)});
            return err;
        };
        // make sure that the entry.dir is the containing dir
        var entry_dir = try entry.dir.openDir(entry.basename, .{});
        defer entry_dir.close();
        num_walked += 1;
    }
    try testing.expectEqual(expected_paths.kvs.len, num_walked);
}

test "walker without fully iterating" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    var tmp = tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    var walker = try tmp.dir.walk(testing.allocator);
    defer walker.deinit();

    // Create 2 directories inside the tmp directory, but then only iterate once before breaking.
    // This ensures that walker doesn't try to close the initial directory when not fully iterating.

    try tmp.dir.makePath("a");
    try tmp.dir.makePath("b");

    var num_walked: usize = 0;
    while (try walker.next()) |_| {
        num_walked += 1;
        break;
    }
    try testing.expectEqual(@as(usize, 1), num_walked);
}

test "'.' and '..' in fs.Dir functions" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    if (native_os == .windows and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/17134
        return error.SkipZigTest;
    }

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            const subdir_path = try ctx.transformPath("./subdir");
            const file_path = try ctx.transformPath("./subdir/../file");
            const copy_path = try ctx.transformPath("./subdir/../copy");
            const rename_path = try ctx.transformPath("./subdir/../rename");
            const update_path = try ctx.transformPath("./subdir/../update");

            try ctx.dir.makeDir(subdir_path);
            try ctx.dir.access(subdir_path, .{});
            var created_subdir = try ctx.dir.openDir(subdir_path, .{});
            created_subdir.close();

            const created_file = try ctx.dir.createFile(file_path, .{});
            created_file.close();
            try ctx.dir.access(file_path, .{});

            try ctx.dir.copyFile(file_path, ctx.dir, copy_path, .{});
            try ctx.dir.rename(copy_path, rename_path);
            const renamed_file = try ctx.dir.openFile(rename_path, .{});
            renamed_file.close();
            try ctx.dir.deleteFile(rename_path);

            try ctx.dir.writeFile(.{ .sub_path = update_path, .data = "something" });
            const prev_status = try ctx.dir.updateFile(file_path, ctx.dir, update_path, .{});
            try testing.expectEqual(fs.Dir.PrevStatus.stale, prev_status);

            try ctx.dir.deleteDir(subdir_path);
        }
    }.impl);
}

test "'.' and '..' in absolute functions" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const subdir_path = try fs.path.join(allocator, &.{ base_path, "./subdir" });
    try fs.makeDirAbsolute(subdir_path);
    try fs.accessAbsolute(subdir_path, .{});
    var created_subdir = try fs.openDirAbsolute(subdir_path, .{});
    created_subdir.close();

    const created_file_path = try fs.path.join(allocator, &.{ subdir_path, "../file" });
    const created_file = try fs.createFileAbsolute(created_file_path, .{});
    created_file.close();
    try fs.accessAbsolute(created_file_path, .{});

    const copied_file_path = try fs.path.join(allocator, &.{ subdir_path, "../copy" });
    try fs.copyFileAbsolute(created_file_path, copied_file_path, .{});
    const renamed_file_path = try fs.path.join(allocator, &.{ subdir_path, "../rename" });
    try fs.renameAbsolute(copied_file_path, renamed_file_path);
    const renamed_file = try fs.openFileAbsolute(renamed_file_path, .{});
    renamed_file.close();
    try fs.deleteFileAbsolute(renamed_file_path);

    const update_file_path = try fs.path.join(allocator, &.{ subdir_path, "../update" });
    const update_file = try fs.createFileAbsolute(update_file_path, .{});
    try update_file.writeAll("something");
    update_file.close();
    const prev_status = try fs.updateFileAbsolute(created_file_path, update_file_path, .{});
    try testing.expectEqual(fs.Dir.PrevStatus.stale, prev_status);

    try fs.deleteDirAbsolute(subdir_path);
}

test "chmod" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .mode = 0o600 });
    defer file.close();
    try testing.expectEqual(@as(File.Mode, 0o600), (try file.stat()).mode & 0o7777);

    try file.chmod(0o644);
    try testing.expectEqual(@as(File.Mode, 0o644), (try file.stat()).mode & 0o7777);

    try tmp.dir.makeDir("test_dir");
    var dir = try tmp.dir.openDir("test_dir", .{ .iterate = true });
    defer dir.close();

    try dir.chmod(0o700);
    try testing.expectEqual(@as(File.Mode, 0o700), (try dir.stat()).mode & 0o7777);
}

test "chown" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{});
    defer file.close();
    try file.chown(null, null);

    try tmp.dir.makeDir("test_dir");

    var dir = try tmp.dir.openDir("test_dir", .{ .iterate = true });
    defer dir.close();
    try dir.chown(null, null);
}

test "File.Metadata" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const metadata = try file.metadata();
    try testing.expectEqual(File.Kind.file, metadata.kind());
    try testing.expectEqual(@as(u64, 0), metadata.size());
    _ = metadata.accessed();
    _ = metadata.modified();
    _ = metadata.created();
}

test "File.Permissions" {
    if (native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const metadata = try file.metadata();
    var permissions = metadata.permissions();

    try testing.expect(!permissions.readOnly());
    permissions.setReadOnly(true);
    try testing.expect(permissions.readOnly());

    try file.setPermissions(permissions);
    const new_permissions = (try file.metadata()).permissions();
    try testing.expect(new_permissions.readOnly());

    // Must be set to non-read-only to delete
    permissions.setReadOnly(false);
    try file.setPermissions(permissions);
}

test "File.PermissionsUnix" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .mode = 0o666, .read = true });
    defer file.close();

    const metadata = try file.metadata();
    var permissions = metadata.permissions();

    permissions.setReadOnly(true);
    try testing.expect(permissions.readOnly());
    try testing.expect(!permissions.inner.unixHas(.user, .write));
    permissions.inner.unixSet(.user, .{ .write = true });
    try testing.expect(!permissions.readOnly());
    try testing.expect(permissions.inner.unixHas(.user, .write));
    try testing.expect(permissions.inner.mode & 0o400 != 0);

    permissions.setReadOnly(true);
    try file.setPermissions(permissions);
    permissions = (try file.metadata()).permissions();
    try testing.expect(permissions.readOnly());

    // Must be set to non-read-only to delete
    permissions.setReadOnly(false);
    try file.setPermissions(permissions);

    const permissions_unix = File.PermissionsUnix.unixNew(0o754);
    try testing.expect(permissions_unix.unixHas(.user, .execute));
    try testing.expect(!permissions_unix.unixHas(.other, .execute));
}

test "delete a read-only file on windows" {
    if (native_os != .windows)
        return error.SkipZigTest;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    defer file.close();
    // Create a file and make it read-only
    const metadata = try file.metadata();
    var permissions = metadata.permissions();
    permissions.setReadOnly(true);
    try file.setPermissions(permissions);

    // If the OS and filesystem support it, POSIX_SEMANTICS and IGNORE_READONLY_ATTRIBUTE
    // is used meaning that the deletion of a read-only file will succeed.
    // Otherwise, this delete will fail and the read-only flag must be unset before it's
    // able to be deleted.
    const delete_result = tmp.dir.deleteFile("test_file");
    if (delete_result) {
        try testing.expectError(error.FileNotFound, tmp.dir.deleteFile("test_file"));
    } else |err| {
        try testing.expectEqual(@as(anyerror, error.AccessDenied), err);
        // Now make the file not read-only
        permissions.setReadOnly(false);
        try file.setPermissions(permissions);
        try tmp.dir.deleteFile("test_file");
    }
}

test "delete a setAsCwd directory on Windows" {
    if (native_os != .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    // Set tmp dir as current working directory.
    try tmp.dir.setAsCwd();
    tmp.dir.close();
    try testing.expectError(error.FileBusy, tmp.parent_dir.deleteTree(&tmp.sub_path));
    // Now set the parent dir as the current working dir for clean up.
    try tmp.parent_dir.setAsCwd();
    try tmp.parent_dir.deleteTree(&tmp.sub_path);
    // Close the parent "tmp" so we don't leak the HANDLE.
    tmp.parent_dir.close();
}

test "invalid UTF-8/WTF-8 paths" {
    const expected_err = switch (native_os) {
        .wasi => error.InvalidUtf8,
        .windows => error.InvalidWtf8,
        else => return error.SkipZigTest,
    };

    try testWithAllSupportedPathTypes(struct {
        fn impl(ctx: *TestContext) !void {
            // This is both invalid UTF-8 and WTF-8, since \xFF is an invalid start byte
            const invalid_path = try ctx.transformPath("\xFF");

            try testing.expectError(expected_err, ctx.dir.openFile(invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.openFileZ(invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.createFile(invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.createFileZ(invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.makeDir(invalid_path));
            try testing.expectError(expected_err, ctx.dir.makeDirZ(invalid_path));

            try testing.expectError(expected_err, ctx.dir.makePath(invalid_path));
            try testing.expectError(expected_err, ctx.dir.makeOpenPath(invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.openDir(invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.openDirZ(invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.deleteFile(invalid_path));
            try testing.expectError(expected_err, ctx.dir.deleteFileZ(invalid_path));

            try testing.expectError(expected_err, ctx.dir.deleteDir(invalid_path));
            try testing.expectError(expected_err, ctx.dir.deleteDirZ(invalid_path));

            try testing.expectError(expected_err, ctx.dir.rename(invalid_path, invalid_path));
            try testing.expectError(expected_err, ctx.dir.renameZ(invalid_path, invalid_path));

            try testing.expectError(expected_err, ctx.dir.symLink(invalid_path, invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.symLinkZ(invalid_path, invalid_path, .{}));
            if (native_os == .wasi) {
                try testing.expectError(expected_err, ctx.dir.symLinkWasi(invalid_path, invalid_path, .{}));
            }

            try testing.expectError(expected_err, ctx.dir.readLink(invalid_path, &[_]u8{}));
            try testing.expectError(expected_err, ctx.dir.readLinkZ(invalid_path, &[_]u8{}));
            if (native_os == .wasi) {
                try testing.expectError(expected_err, ctx.dir.readLinkWasi(invalid_path, &[_]u8{}));
            }

            try testing.expectError(expected_err, ctx.dir.readFile(invalid_path, &[_]u8{}));
            try testing.expectError(expected_err, ctx.dir.readFileAlloc(testing.allocator, invalid_path, 0));

            try testing.expectError(expected_err, ctx.dir.deleteTree(invalid_path));
            try testing.expectError(expected_err, ctx.dir.deleteTreeMinStackSize(invalid_path));

            try testing.expectError(expected_err, ctx.dir.writeFile(.{ .sub_path = invalid_path, .data = "" }));

            try testing.expectError(expected_err, ctx.dir.access(invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.accessZ(invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.updateFile(invalid_path, ctx.dir, invalid_path, .{}));
            try testing.expectError(expected_err, ctx.dir.copyFile(invalid_path, ctx.dir, invalid_path, .{}));

            try testing.expectError(expected_err, ctx.dir.statFile(invalid_path));

            if (native_os != .wasi) {
                try testing.expectError(expected_err, ctx.dir.realpath(invalid_path, &[_]u8{}));
                try testing.expectError(expected_err, ctx.dir.realpathZ(invalid_path, &[_]u8{}));
                try testing.expectError(expected_err, ctx.dir.realpathAlloc(testing.allocator, invalid_path));
            }

            try testing.expectError(expected_err, fs.rename(ctx.dir, invalid_path, ctx.dir, invalid_path));
            try testing.expectError(expected_err, fs.renameZ(ctx.dir, invalid_path, ctx.dir, invalid_path));

            if (native_os != .wasi and ctx.path_type != .relative) {
                try testing.expectError(expected_err, fs.updateFileAbsolute(invalid_path, invalid_path, .{}));
                try testing.expectError(expected_err, fs.copyFileAbsolute(invalid_path, invalid_path, .{}));
                try testing.expectError(expected_err, fs.makeDirAbsolute(invalid_path));
                try testing.expectError(expected_err, fs.makeDirAbsoluteZ(invalid_path));
                try testing.expectError(expected_err, fs.deleteDirAbsolute(invalid_path));
                try testing.expectError(expected_err, fs.deleteDirAbsoluteZ(invalid_path));
                try testing.expectError(expected_err, fs.renameAbsolute(invalid_path, invalid_path));
                try testing.expectError(expected_err, fs.renameAbsoluteZ(invalid_path, invalid_path));
                try testing.expectError(expected_err, fs.openDirAbsolute(invalid_path, .{}));
                try testing.expectError(expected_err, fs.openDirAbsoluteZ(invalid_path, .{}));
                try testing.expectError(expected_err, fs.openFileAbsolute(invalid_path, .{}));
                try testing.expectError(expected_err, fs.openFileAbsoluteZ(invalid_path, .{}));
                try testing.expectError(expected_err, fs.accessAbsolute(invalid_path, .{}));
                try testing.expectError(expected_err, fs.accessAbsoluteZ(invalid_path, .{}));
                try testing.expectError(expected_err, fs.createFileAbsolute(invalid_path, .{}));
                try testing.expectError(expected_err, fs.createFileAbsoluteZ(invalid_path, .{}));
                try testing.expectError(expected_err, fs.deleteFileAbsolute(invalid_path));
                try testing.expectError(expected_err, fs.deleteFileAbsoluteZ(invalid_path));
                try testing.expectError(expected_err, fs.deleteTreeAbsolute(invalid_path));
                var readlink_buf: [fs.max_path_bytes]u8 = undefined;
                try testing.expectError(expected_err, fs.readLinkAbsolute(invalid_path, &readlink_buf));
                try testing.expectError(expected_err, fs.readLinkAbsoluteZ(invalid_path, &readlink_buf));
                try testing.expectError(expected_err, fs.symLinkAbsolute(invalid_path, invalid_path, .{}));
                try testing.expectError(expected_err, fs.symLinkAbsoluteZ(invalid_path, invalid_path, .{}));
                try testing.expectError(expected_err, fs.realpathAlloc(testing.allocator, invalid_path));
            }
        }
    }.impl);
}
