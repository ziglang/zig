const Package = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Hash = std.crypto.hash.sha2.Sha256;

const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const ThreadPool = @import("ThreadPool.zig");

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

pub fn fetchAndAddDependencies(
    pkg: *Package,
    thread_pool: *ThreadPool,
    http_client: *std.http.Client,
    directory: Compilation.Directory,
    global_cache_directory: Compilation.Directory,
    local_cache_directory: Compilation.Directory,
) !void {
    const max_bytes = 10 * 1024 * 1024;
    const gpa = thread_pool.allocator;
    const build_zig_ini = directory.handle.readFileAlloc(gpa, "build.zig.ini", max_bytes) catch |err| switch (err) {
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
        var opt_id: ?[]const u8 = null;
        var opt_url: ?[]const u8 = null;
        var expected_hash: ?[Hash.digest_length]u8 = null;
        while (line_it.next()) |kv| {
            const eq_pos = mem.indexOfScalar(u8, kv, '=') orelse continue;
            const key = kv[0..eq_pos];
            const value = kv[eq_pos + 1 ..];
            if (mem.eql(u8, key, "id")) {
                opt_id = value;
            } else if (mem.eql(u8, key, "url")) {
                opt_url = value;
            } else if (mem.eql(u8, key, "hash")) {
                @panic("TODO parse hex digits of value into expected_hash");
                //expected_hash = value;
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

        const id = opt_id orelse {
            const loc = std.zig.findLineColumn(ini.bytes, @ptrToInt(dep.ptr) - @ptrToInt(ini.bytes.ptr));
            std.log.err("{s}/{s}:{d}:{d} missing key: 'id'", .{
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
            std.log.err("{s}/{s}:{d}:{d} missing key: 'id'", .{
                directory.path orelse ".",
                "build.zig.ini",
                loc.line,
                loc.column,
            });
            any_error = true;
            continue;
        };

        const sub_pkg = try fetchAndUnpack(http_client, global_cache_directory, url, expected_hash);

        try sub_pkg.fetchAndAddDependencies(
            thread_pool,
            http_client,
            sub_pkg.root_src_directory,
            global_cache_directory,
            local_cache_directory,
        );

        try addAndAdopt(pkg, gpa, id, sub_pkg);
    }

    if (any_error) return error.InvalidBuildZigIniFile;
}

fn fetchAndUnpack(
    http_client: *std.http.Client,
    global_cache_directory: Compilation.Directory,
    url: []const u8,
    expected_hash: ?[Hash.digest_length]u8,
) !*Package {
    const gpa = http_client.allocator;

    // TODO check if the expected_hash is already present in the global package cache, and
    // thereby avoid both fetching and unpacking.

    const uri = try std.Uri.parse(url);

    var tmp_directory: Compilation.Directory = d: {
        const s = fs.path.sep_str;
        const rand_int = std.crypto.random.int(u64);

        const tmp_dir_sub_path = try std.fmt.allocPrint(gpa, "tmp" ++ s ++ "{x}", .{rand_int});

        const path = try global_cache_directory.join(gpa, &.{tmp_dir_sub_path});
        errdefer gpa.free(path);

        const handle = try global_cache_directory.handle.makeOpenPath(tmp_dir_sub_path, .{});
        errdefer handle.close();

        break :d .{
            .path = path,
            .handle = handle,
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

        try std.tar.pipeToFileSystem(tmp_directory.handle, gzip_stream.reader(), .{});
    } else {
        // TODO: show the build.zig.ini file and line number
        std.log.err("{s}: unknown package extension for path '{s}'", .{ url, uri.path });
        return error.UnknownPackageExtension;
    }

    // TODO: delete files not included in the package prior to computing the package hash.
    // for example, if the ini file has directives to include/not include certain files,
    // apply those rules directly to the filesystem right here. This ensures that files
    // not protected by the hash are not present on the file system.

    const actual_hash = try computePackageHash(tmp_directory);

    if (expected_hash) |h| {
        if (!mem.eql(u8, &h, &actual_hash)) {
            // TODO: show the build.zig.ini file and line number
            std.log.err("{s}: hash mismatch: expected: {s}, actual: {s}", .{
                url, h, actual_hash,
            });
            return error.PackageHashMismatch;
        }
    }

    if (true) @panic("TODO move the tmp dir into place");

    if (expected_hash == null) {
        // TODO: show the build.zig.ini file and line number
        std.log.err("{s}: missing hash:\nhash={s}", .{
            url, actual_hash,
        });
        return error.PackageDependencyMissingHash;
    }

    @panic("TODO create package and set root_src_directory");
    //return create(gpa, root_src
    //gpa: Allocator,
    ///// Null indicates the current working directory
    //root_src_dir_path: ?[]const u8,
    ///// Relative to root_src_dir_path
    //root_src_path: []const u8,
}

fn computePackageHash(pkg_directory: Compilation.Directory) ![Hash.digest_length]u8 {
    _ = pkg_directory;
    @panic("TODO computePackageHash");
}
