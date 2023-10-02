const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const Allocator = std.mem.Allocator;

const Hash = @import("../Manifest.zig").Hash;

pub fn compute(thread_pool: *ThreadPool, pkg_dir: fs.IterableDir) ![Hash.digest_length]u8 {
    const gpa = thread_pool.allocator;

    // We'll use an arena allocator for the path name strings since they all
    // need to be in memory for sorting.
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // TODO: delete files not included in the package prior to computing the package hash.
    // for example, if the ini file has directives to include/not include certain files,
    // apply those rules directly to the filesystem right here. This ensures that files
    // not protected by the hash are not present on the file system.

    // Collect all files, recursively, then sort.
    var all_files = std.ArrayList(*HashedFile).init(gpa);
    defer all_files.deinit();

    var walker = try pkg_dir.walk(gpa);
    defer walker.deinit();

    {
        // The final hash will be a hash of each file hashed independently. This
        // allows hashing in parallel.
        var wait_group: WaitGroup = .{};
        defer wait_group.wait();

        while (try walker.next()) |entry| {
            const kind: HashedFile.Kind = switch (entry.kind) {
                .directory => continue,
                .file => .file,
                .sym_link => .sym_link,
                else => return error.IllegalFileTypeInPackage,
            };
            const hashed_file = try arena.create(HashedFile);
            const fs_path = try arena.dupe(u8, entry.path);
            hashed_file.* = .{
                .fs_path = fs_path,
                .normalized_path = try normalizePath(arena, fs_path),
                .kind = kind,
                .hash = undefined, // to be populated by the worker
                .failure = undefined, // to be populated by the worker
            };
            wait_group.start();
            try thread_pool.spawn(workerHashFile, .{ pkg_dir.dir, hashed_file, &wait_group });

            try all_files.append(hashed_file);
        }
    }

    std.mem.sortUnstable(*HashedFile, all_files.items, {}, HashedFile.lessThan);

    var hasher = Hash.init(.{});
    var any_failures = false;
    for (all_files.items) |hashed_file| {
        hashed_file.failure catch |err| {
            any_failures = true;
            std.log.err("unable to hash '{s}': {s}", .{ hashed_file.fs_path, @errorName(err) });
        };
        hasher.update(&hashed_file.hash);
    }
    if (any_failures) return error.PackageHashUnavailable;
    return hasher.finalResult();
}

const HashedFile = struct {
    fs_path: []const u8,
    normalized_path: []const u8,
    hash: [Hash.digest_length]u8,
    failure: Error!void,
    kind: Kind,

    const Error =
        fs.File.OpenError ||
        fs.File.ReadError ||
        fs.File.StatError ||
        fs.Dir.ReadLinkError;

    const Kind = enum { file, sym_link };

    fn lessThan(context: void, lhs: *const HashedFile, rhs: *const HashedFile) bool {
        _ = context;
        return std.mem.lessThan(u8, lhs.normalized_path, rhs.normalized_path);
    }
};

/// Make a file system path identical independently of operating system path inconsistencies.
/// This converts backslashes into forward slashes.
fn normalizePath(arena: Allocator, fs_path: []const u8) ![]const u8 {
    const canonical_sep = '/';

    if (fs.path.sep == canonical_sep)
        return fs_path;

    const normalized = try arena.dupe(u8, fs_path);
    for (normalized) |*byte| {
        switch (byte.*) {
            fs.path.sep => byte.* = canonical_sep,
            else => continue,
        }
    }
    return normalized;
}

fn workerHashFile(dir: fs.Dir, hashed_file: *HashedFile, wg: *WaitGroup) void {
    defer wg.finish();
    hashed_file.failure = hashFileFallible(dir, hashed_file);
}

fn hashFileFallible(dir: fs.Dir, hashed_file: *HashedFile) HashedFile.Error!void {
    var buf: [8000]u8 = undefined;
    var hasher = Hash.init(.{});
    hasher.update(hashed_file.normalized_path);
    switch (hashed_file.kind) {
        .file => {
            var file = try dir.openFile(hashed_file.fs_path, .{});
            defer file.close();
            hasher.update(&.{ 0, @intFromBool(try isExecutable(file)) });
            while (true) {
                const bytes_read = try file.read(&buf);
                if (bytes_read == 0) break;
                hasher.update(buf[0..bytes_read]);
            }
        },
        .sym_link => {
            const link_name = try dir.readLink(hashed_file.fs_path, &buf);
            hasher.update(link_name);
        },
    }
    hasher.final(&hashed_file.hash);
}

fn isExecutable(file: fs.File) !bool {
    if (builtin.os.tag == .windows) {
        // TODO check the ACL on Windows.
        // Until this is implemented, this could be a false negative on
        // Windows, which is why we do not yet set executable_bit_only above
        // when unpacking the tarball.
        return false;
    } else {
        const stat = try file.stat();
        return (stat.mode & std.os.S.IXUSR) != 0;
    }
}
