const Package = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Hash = std.crypto.hash.sha2.Sha256;
const log = std.log.scoped(.package);

const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const Cache = @import("Cache.zig");
const build_options = @import("build_options");

pub const Table = std.StringHashMapUnmanaged(*Package);

root_src_directory: Compilation.Directory,
/// Relative to `root_src_directory`. May contain path separators.
root_src_path: []const u8,
table: Table = .{},
parent: ?*Package = null,
/// Whether to free `root_src_directory` on `destroy`.
root_src_directory_owned: bool = false,

/// Allocate a Package. No references to the slices passed are kept.
pub fn create(
    gpa: Allocator,
    /// Null indicates the current working directory
    root_src_dir_path: ?[]const u8,
    /// Relative to root_src_dir_path
    root_src_path: []const u8,
) !*Package {
    const ptr = try gpa.create(Package);
    errdefer gpa.destroy(ptr);

    const owned_dir_path = if (root_src_dir_path) |p| try gpa.dupe(u8, p) else null;
    errdefer if (owned_dir_path) |p| gpa.free(p);

    const owned_src_path = try gpa.dupe(u8, root_src_path);
    errdefer gpa.free(owned_src_path);

    ptr.* = .{
        .root_src_directory = .{
            .path = owned_dir_path,
            .handle = if (owned_dir_path) |p| try fs.cwd().openDir(p, .{}) else fs.cwd(),
        },
        .root_src_path = owned_src_path,
        .root_src_directory_owned = true,
    };

    return ptr;
}

pub fn createWithDir(
    gpa: Allocator,
    directory: Compilation.Directory,
    /// Relative to `directory`. If null, means `directory` is the root src dir
    /// and is owned externally.
    root_src_dir_path: ?[]const u8,
    /// Relative to root_src_dir_path
    root_src_path: []const u8,
) !*Package {
    const ptr = try gpa.create(Package);
    errdefer gpa.destroy(ptr);

    const owned_src_path = try gpa.dupe(u8, root_src_path);
    errdefer gpa.free(owned_src_path);

    if (root_src_dir_path) |p| {
        const owned_dir_path = try directory.join(gpa, &[1][]const u8{p});
        errdefer gpa.free(owned_dir_path);

        ptr.* = .{
            .root_src_directory = .{
                .path = owned_dir_path,
                .handle = try directory.handle.openDir(p, .{}),
            },
            .root_src_directory_owned = true,
            .root_src_path = owned_src_path,
        };
    } else {
        ptr.* = .{
            .root_src_directory = directory,
            .root_src_directory_owned = false,
            .root_src_path = owned_src_path,
        };
    }
    return ptr;
}

/// Free all memory associated with this package. It does not destroy any packages
/// inside its table; the caller is responsible for calling destroy() on them.
pub fn destroy(pkg: *Package, gpa: Allocator) void {
    gpa.free(pkg.root_src_path);

    if (pkg.root_src_directory_owned) {
        // If root_src_directory.path is null then the handle is the cwd()
        // which shouldn't be closed.
        if (pkg.root_src_directory.path) |p| {
            gpa.free(p);
            pkg.root_src_directory.handle.close();
        }
    }

    pkg.deinitTable(gpa);
    gpa.destroy(pkg);
}

/// Only frees memory associated with the table.
pub fn deinitTable(pkg: *Package, gpa: Allocator) void {
    var it = pkg.table.keyIterator();
    while (it.next()) |key| {
        gpa.free(key.*);
    }

    pkg.table.deinit(gpa);
}

pub fn add(pkg: *Package, gpa: Allocator, name: []const u8, package: *Package) !void {
    try pkg.table.ensureUnusedCapacity(gpa, 1);
    const name_dupe = try gpa.dupe(u8, name);
    pkg.table.putAssumeCapacityNoClobber(name_dupe, package);
}

pub fn addAndAdopt(parent: *Package, gpa: Allocator, name: []const u8, child: *Package) !void {
    assert(child.parent == null); // make up your mind, who is the parent??
    child.parent = parent;
    return parent.add(gpa, name, child);
}

pub const build_zig_basename = "build.zig";
pub const ini_basename = build_zig_basename ++ ".ini";

pub fn fetchAndAddDependencies(
    pkg: *Package,
    thread_pool: *ThreadPool,
    http_client: *std.http.Client,
    directory: Compilation.Directory,
    global_cache_directory: Compilation.Directory,
    local_cache_directory: Compilation.Directory,
    dependencies_source: *std.ArrayList(u8),
    build_roots_source: *std.ArrayList(u8),
    name_prefix: []const u8,
) !void {
    const max_bytes = 10 * 1024 * 1024;
    const gpa = thread_pool.allocator;
    const build_zig_ini = directory.handle.readFileAlloc(gpa, ini_basename, max_bytes) catch |err| switch (err) {
        error.FileNotFound => {
            // Handle the same as no dependencies.
            return;
        },
        else => |e| return e,
    };
    defer gpa.free(build_zig_ini);

    const ini: std.Ini = .{ .bytes = build_zig_ini };
    var any_error = false;
    var it = ini.iterateSection("\n[dependency]\n");
    while (it.next()) |dep| {
        var line_it = mem.split(u8, dep, "\n");
        var opt_name: ?[]const u8 = null;
        var opt_url: ?[]const u8 = null;
        var expected_hash: ?[]const u8 = null;
        while (line_it.next()) |kv| {
            const eq_pos = mem.indexOfScalar(u8, kv, '=') orelse continue;
            const key = kv[0..eq_pos];
            const value = kv[eq_pos + 1 ..];
            if (mem.eql(u8, key, "name")) {
                opt_name = value;
            } else if (mem.eql(u8, key, "url")) {
                opt_url = value;
            } else if (mem.eql(u8, key, "hash")) {
                expected_hash = value;
            } else {
                const loc = std.zig.findLineColumn(ini.bytes, @ptrToInt(key.ptr) - @ptrToInt(ini.bytes.ptr));
                std.log.warn("{s}/{s}:{d}:{d} unrecognized key: '{s}'", .{
                    directory.path orelse ".",
                    "build.zig.ini",
                    loc.line,
                    loc.column,
                    key,
                });
            }
        }

        const name = opt_name orelse {
            const loc = std.zig.findLineColumn(ini.bytes, @ptrToInt(dep.ptr) - @ptrToInt(ini.bytes.ptr));
            std.log.err("{s}/{s}:{d}:{d} missing key: 'name'", .{
                directory.path orelse ".",
                "build.zig.ini",
                loc.line,
                loc.column,
            });
            any_error = true;
            continue;
        };

        const url = opt_url orelse {
            const loc = std.zig.findLineColumn(ini.bytes, @ptrToInt(dep.ptr) - @ptrToInt(ini.bytes.ptr));
            std.log.err("{s}/{s}:{d}:{d} missing key: 'name'", .{
                directory.path orelse ".",
                "build.zig.ini",
                loc.line,
                loc.column,
            });
            any_error = true;
            continue;
        };

        const sub_prefix = try std.fmt.allocPrint(gpa, "{s}{s}.", .{ name_prefix, name });
        defer gpa.free(sub_prefix);
        const fqn = sub_prefix[0 .. sub_prefix.len - 1];

        const sub_pkg = try fetchAndUnpack(
            thread_pool,
            http_client,
            global_cache_directory,
            url,
            expected_hash,
            ini,
            directory,
            build_roots_source,
            fqn,
        );

        try pkg.fetchAndAddDependencies(
            thread_pool,
            http_client,
            sub_pkg.root_src_directory,
            global_cache_directory,
            local_cache_directory,
            dependencies_source,
            build_roots_source,
            sub_prefix,
        );

        try addAndAdopt(pkg, gpa, fqn, sub_pkg);

        try dependencies_source.writer().print("    pub const {s} = @import(\"{}\");\n", .{
            std.zig.fmtId(fqn), std.zig.fmtEscapes(fqn),
        });
    }

    if (any_error) return error.InvalidBuildZigIniFile;
}

pub fn createFilePkg(
    gpa: Allocator,
    cache_directory: Compilation.Directory,
    basename: []const u8,
    contents: []const u8,
) !*Package {
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ fs.path.sep_str ++ hex64(rand_int);
    {
        var tmp_dir = try cache_directory.handle.makeOpenPath(tmp_dir_sub_path, .{});
        defer tmp_dir.close();
        try tmp_dir.writeFile(basename, contents);
    }

    var hh: Cache.HashHelper = .{};
    hh.addBytes(build_options.version);
    hh.addBytes(contents);
    const hex_digest = hh.final();

    const o_dir_sub_path = "o" ++ fs.path.sep_str ++ hex_digest;
    try renameTmpIntoCache(cache_directory.handle, tmp_dir_sub_path, o_dir_sub_path);

    return createWithDir(gpa, cache_directory, o_dir_sub_path, basename);
}

fn fetchAndUnpack(
    thread_pool: *ThreadPool,
    http_client: *std.http.Client,
    global_cache_directory: Compilation.Directory,
    url: []const u8,
    expected_hash: ?[]const u8,
    ini: std.Ini,
    comp_directory: Compilation.Directory,
    build_roots_source: *std.ArrayList(u8),
    fqn: []const u8,
) !*Package {
    const gpa = http_client.allocator;
    const s = fs.path.sep_str;

    // Check if the expected_hash is already present in the global package
    // cache, and thereby avoid both fetching and unpacking.
    if (expected_hash) |h| cached: {
        if (h.len != 2 * Hash.digest_length) {
            return reportError(
                ini,
                comp_directory,
                h.ptr,
                "wrong hash size. expected: {d}, found: {d}",
                .{ Hash.digest_length, h.len },
            );
        }
        const hex_digest = h[0 .. 2 * Hash.digest_length];
        const pkg_dir_sub_path = "p" ++ s ++ hex_digest;
        var pkg_dir = global_cache_directory.handle.openDir(pkg_dir_sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :cached,
            else => |e| return e,
        };
        errdefer pkg_dir.close();

        const ptr = try gpa.create(Package);
        errdefer gpa.destroy(ptr);

        const owned_src_path = try gpa.dupe(u8, build_zig_basename);
        errdefer gpa.free(owned_src_path);

        const build_root = try global_cache_directory.join(gpa, &.{pkg_dir_sub_path});
        errdefer gpa.free(build_root);

        try build_roots_source.writer().print("    pub const {s} = \"{}\";\n", .{
            std.zig.fmtId(fqn), std.zig.fmtEscapes(build_root),
        });

        ptr.* = .{
            .root_src_directory = .{
                .path = build_root,
                .handle = pkg_dir,
            },
            .root_src_directory_owned = true,
            .root_src_path = owned_src_path,
        };

        return ptr;
    }

    const uri = try std.Uri.parse(url);

    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ s ++ hex64(rand_int);

    const actual_hash = a: {
        var tmp_directory: Compilation.Directory = d: {
            const path = try global_cache_directory.join(gpa, &.{tmp_dir_sub_path});
            errdefer gpa.free(path);

            const iterable_dir = try global_cache_directory.handle.makeOpenPathIterable(tmp_dir_sub_path, .{});
            errdefer iterable_dir.close();

            break :d .{
                .path = path,
                .handle = iterable_dir.dir,
            };
        };
        defer tmp_directory.closeAndFree(gpa);

        var req = try http_client.request(uri, .{}, .{});
        defer req.deinit();

        if (mem.endsWith(u8, uri.path, ".tar.gz")) {
            // I observed the gzip stream to read 1 byte at a time, so I am using a
            // buffered reader on the front of it.
            var br = std.io.bufferedReaderSize(std.crypto.tls.max_ciphertext_record_len, req.reader());

            var gzip_stream = try std.compress.gzip.gzipStream(gpa, br.reader());
            defer gzip_stream.deinit();

            try std.tar.pipeToFileSystem(tmp_directory.handle, gzip_stream.reader(), .{
                .strip_components = 1,
            });
        } else {
            return reportError(
                ini,
                comp_directory,
                uri.path.ptr,
                "unknown file extension for path '{s}'",
                .{uri.path},
            );
        }

        // TODO: delete files not included in the package prior to computing the package hash.
        // for example, if the ini file has directives to include/not include certain files,
        // apply those rules directly to the filesystem right here. This ensures that files
        // not protected by the hash are not present on the file system.

        break :a try computePackageHash(thread_pool, .{ .dir = tmp_directory.handle });
    };

    const pkg_dir_sub_path = "p" ++ s ++ hexDigest(actual_hash);
    try renameTmpIntoCache(global_cache_directory.handle, tmp_dir_sub_path, pkg_dir_sub_path);

    if (expected_hash) |h| {
        const actual_hex = hexDigest(actual_hash);
        if (!mem.eql(u8, h, &actual_hex)) {
            return reportError(
                ini,
                comp_directory,
                h.ptr,
                "hash mismatch: expected: {s}, found: {s}",
                .{ h, actual_hex },
            );
        }
    } else {
        return reportError(
            ini,
            comp_directory,
            url.ptr,
            "url field is missing corresponding hash field: hash={s}",
            .{std.fmt.fmtSliceHexLower(&actual_hash)},
        );
    }

    const build_root = try global_cache_directory.join(gpa, &.{pkg_dir_sub_path});
    defer gpa.free(build_root);

    try build_roots_source.writer().print("    pub const {s} = \"{}\";\n", .{
        std.zig.fmtId(fqn), std.zig.fmtEscapes(build_root),
    });

    return createWithDir(gpa, global_cache_directory, pkg_dir_sub_path, build_zig_basename);
}

fn reportError(
    ini: std.Ini,
    comp_directory: Compilation.Directory,
    src_ptr: [*]const u8,
    comptime fmt_string: []const u8,
    fmt_args: anytype,
) error{PackageFetchFailed} {
    const loc = std.zig.findLineColumn(ini.bytes, @ptrToInt(src_ptr) - @ptrToInt(ini.bytes.ptr));
    if (comp_directory.path) |p| {
        std.debug.print("{s}{c}{s}:{d}:{d}: error: " ++ fmt_string ++ "\n", .{
            p, fs.path.sep, ini_basename, loc.line + 1, loc.column + 1,
        } ++ fmt_args);
    } else {
        std.debug.print("{s}:{d}:{d}: error: " ++ fmt_string ++ "\n", .{
            ini_basename, loc.line + 1, loc.column + 1,
        } ++ fmt_args);
    }
    return error.PackageFetchFailed;
}

const HashedFile = struct {
    path: []const u8,
    hash: [Hash.digest_length]u8,
    failure: Error!void,

    const Error = fs.File.OpenError || fs.File.ReadError;

    fn lessThan(context: void, lhs: *const HashedFile, rhs: *const HashedFile) bool {
        _ = context;
        return mem.lessThan(u8, lhs.path, rhs.path);
    }
};

fn computePackageHash(
    thread_pool: *ThreadPool,
    pkg_dir: fs.IterableDir,
) ![Hash.digest_length]u8 {
    const gpa = thread_pool.allocator;

    // We'll use an arena allocator for the path name strings since they all
    // need to be in memory for sorting.
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

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
            switch (entry.kind) {
                .Directory => continue,
                .File => {},
                else => return error.IllegalFileTypeInPackage,
            }
            const hashed_file = try arena.create(HashedFile);
            hashed_file.* = .{
                .path = try arena.dupe(u8, entry.path),
                .hash = undefined, // to be populated by the worker
                .failure = undefined, // to be populated by the worker
            };
            wait_group.start();
            try thread_pool.spawn(workerHashFile, .{ pkg_dir.dir, hashed_file, &wait_group });

            try all_files.append(hashed_file);
        }
    }

    std.sort.sort(*HashedFile, all_files.items, {}, HashedFile.lessThan);

    var hasher = Hash.init(.{});
    var any_failures = false;
    for (all_files.items) |hashed_file| {
        hashed_file.failure catch |err| {
            any_failures = true;
            std.log.err("unable to hash '{s}': {s}", .{ hashed_file.path, @errorName(err) });
        };
        hasher.update(&hashed_file.hash);
    }
    if (any_failures) return error.PackageHashUnavailable;
    return hasher.finalResult();
}

fn workerHashFile(dir: fs.Dir, hashed_file: *HashedFile, wg: *WaitGroup) void {
    defer wg.finish();
    hashed_file.failure = hashFileFallible(dir, hashed_file);
}

fn hashFileFallible(dir: fs.Dir, hashed_file: *HashedFile) HashedFile.Error!void {
    var buf: [8000]u8 = undefined;
    var file = try dir.openFile(hashed_file.path, .{});
    var hasher = Hash.init(.{});
    while (true) {
        const bytes_read = try file.read(&buf);
        if (bytes_read == 0) break;
        hasher.update(buf[0..bytes_read]);
    }
    hasher.final(&hashed_file.hash);
}

const hex_charset = "0123456789abcdef";

fn hex64(x: u64) [16]u8 {
    var result: [16]u8 = undefined;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const byte = @truncate(u8, x >> @intCast(u6, 8 * i));
        result[i * 2 + 0] = hex_charset[byte >> 4];
        result[i * 2 + 1] = hex_charset[byte & 15];
    }
    return result;
}

test hex64 {
    const s = "[" ++ hex64(0x12345678_abcdef00) ++ "]";
    try std.testing.expectEqualStrings("[00efcdab78563412]", s);
}

fn hexDigest(digest: [Hash.digest_length]u8) [Hash.digest_length * 2]u8 {
    var result: [Hash.digest_length * 2]u8 = undefined;
    for (digest) |byte, i| {
        result[i * 2 + 0] = hex_charset[byte >> 4];
        result[i * 2 + 1] = hex_charset[byte & 15];
    }
    return result;
}

fn renameTmpIntoCache(
    cache_dir: fs.Dir,
    tmp_dir_sub_path: []const u8,
    dest_dir_sub_path: []const u8,
) !void {
    assert(dest_dir_sub_path[1] == fs.path.sep);
    var handled_missing_dir = false;
    while (true) {
        cache_dir.rename(tmp_dir_sub_path, dest_dir_sub_path) catch |err| switch (err) {
            error.FileNotFound => {
                if (handled_missing_dir) return err;
                cache_dir.makeDir(dest_dir_sub_path[0..1]) catch |mkd_err| switch (mkd_err) {
                    error.PathAlreadyExists => handled_missing_dir = true,
                    else => |e| return e,
                };
                continue;
            },
            error.PathAlreadyExists, error.AccessDenied => {
                // Package has been already downloaded and may already be in use on the system.
                cache_dir.deleteTree(tmp_dir_sub_path) catch |del_err| {
                    std.log.warn("unable to delete temp directory: {s}", .{@errorName(del_err)});
                };
            },
            else => |e| return e,
        };
        break;
    }
}
