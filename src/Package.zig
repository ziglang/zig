const Package = @This();

const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.package);
const main = @import("main.zig");

const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const Cache = std.Build.Cache;
const build_options = @import("build_options");
const Manifest = @import("Manifest.zig");

pub const Table = std.StringHashMapUnmanaged(*Package);

root_src_directory: Compilation.Directory,
/// Relative to `root_src_directory`. May contain path separators.
root_src_path: []const u8,
/// The dependency table of this module. Shared dependencies such as 'std', 'builtin', and 'root'
/// are not specified in every dependency table, but instead only in the table of `main_pkg`.
/// `Module.importFile` is responsible for detecting these names and using the correct package.
table: Table = .{},
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
    pkg.table.deinit(gpa);
}

pub fn add(pkg: *Package, gpa: Allocator, name: []const u8, package: *Package) !void {
    try pkg.table.ensureUnusedCapacity(gpa, 1);
    const name_dupe = try gpa.dupe(u8, name);
    pkg.table.putAssumeCapacityNoClobber(name_dupe, package);
}

/// Compute a readable name for the package. The returned name should be freed from gpa. This
/// function is very slow, as it traverses the whole package hierarchy to find a path to this
/// package. It should only be used for error output.
pub fn getName(target: *const Package, gpa: Allocator, mod: Module) ![]const u8 {
    // we'll do a breadth-first search from the root module to try and find a short name for this
    // module, using a TailQueue of module/parent pairs. note that the "parent" there is just the
    // first-found shortest path - a module may be children of arbitrarily many other modules.
    // also, this path may vary between executions due to hashmap iteration order, but that doesn't
    // matter too much.
    var node_arena = std.heap.ArenaAllocator.init(gpa);
    defer node_arena.deinit();
    const Parented = struct {
        parent: ?*const @This(),
        mod: *const Package,
    };
    const Queue = std.TailQueue(Parented);
    var to_check: Queue = .{};

    {
        const new = try node_arena.allocator().create(Queue.Node);
        new.* = .{ .data = .{ .parent = null, .mod = mod.root_pkg } };
        to_check.prepend(new);
    }

    if (mod.main_pkg != mod.root_pkg) {
        const new = try node_arena.allocator().create(Queue.Node);
        // TODO: once #12201 is resolved, we may want a way of indicating a different name for this
        new.* = .{ .data = .{ .parent = null, .mod = mod.main_pkg } };
        to_check.prepend(new);
    }

    // set of modules we've already checked to prevent loops
    var checked = std.AutoHashMap(*const Package, void).init(gpa);
    defer checked.deinit();

    const linked = while (to_check.pop()) |node| {
        const check = &node.data;

        if (checked.contains(check.mod)) continue;
        try checked.put(check.mod, {});

        if (check.mod == target) break check;

        var it = check.mod.table.iterator();
        while (it.next()) |kv| {
            var new = try node_arena.allocator().create(Queue.Node);
            new.* = .{ .data = .{
                .parent = check,
                .mod = kv.value_ptr.*,
            } };
            to_check.prepend(new);
        }
    } else {
        // this can happen for e.g. @cImport packages
        return gpa.dupe(u8, "<unnamed>");
    };

    // we found a path to the module! unfortunately, we can only traverse *up* it, so we have to put
    // all the names into a buffer so we can then print them in order.
    var names = std.ArrayList([]const u8).init(gpa);
    defer names.deinit();

    var cur: *const Parented = linked;
    while (cur.parent) |parent| : (cur = parent) {
        // find cur's name in parent
        var it = parent.mod.table.iterator();
        const name = while (it.next()) |kv| {
            if (kv.value_ptr.* == cur.mod) {
                break kv.key_ptr.*;
            }
        } else unreachable;
        try names.append(name);
    }

    // finally, print the names into a buffer!
    var buf = std.ArrayList(u8).init(gpa);
    defer buf.deinit();
    try buf.writer().writeAll("root");
    var i: usize = names.items.len;
    while (i > 0) {
        i -= 1;
        try buf.writer().print(".{s}", .{names.items[i]});
    }

    return buf.toOwnedSlice();
}

pub const build_zig_basename = "build.zig";

pub fn fetchAndAddDependencies(
    pkg: *Package,
    arena: Allocator,
    thread_pool: *ThreadPool,
    http_client: *std.http.Client,
    directory: Compilation.Directory,
    global_cache_directory: Compilation.Directory,
    local_cache_directory: Compilation.Directory,
    dependencies_source: *std.ArrayList(u8),
    build_roots_source: *std.ArrayList(u8),
    name_prefix: []const u8,
    color: main.Color,
    all_modules: *AllModules,
) !void {
    const max_bytes = 10 * 1024 * 1024;
    const gpa = thread_pool.allocator;
    const build_zig_zon_bytes = directory.handle.readFileAllocOptions(
        arena,
        Manifest.basename,
        max_bytes,
        null,
        1,
        0,
    ) catch |err| switch (err) {
        error.FileNotFound => {
            // Handle the same as no dependencies.
            return;
        },
        else => |e| return e,
    };

    var ast = try std.zig.Ast.parse(gpa, build_zig_zon_bytes, .zon);
    defer ast.deinit(gpa);

    if (ast.errors.len > 0) {
        const file_path = try directory.join(arena, &.{Manifest.basename});
        try main.printErrsMsgToStdErr(gpa, arena, ast, file_path, color);
        return error.PackageFetchFailed;
    }

    var manifest = try Manifest.parse(gpa, ast);
    defer manifest.deinit(gpa);

    if (manifest.errors.len > 0) {
        const ttyconf: std.debug.TTY.Config = switch (color) {
            .auto => std.debug.detectTTYConfig(std.io.getStdErr()),
            .on => .escape_codes,
            .off => .no_color,
        };
        const file_path = try directory.join(arena, &.{Manifest.basename});
        for (manifest.errors) |msg| {
            Report.renderErrorMessage(ast, file_path, ttyconf, msg, &.{});
        }
        return error.PackageFetchFailed;
    }

    const report: Report = .{
        .ast = &ast,
        .directory = directory,
        .color = color,
        .arena = arena,
    };

    var any_error = false;
    const deps_list = manifest.dependencies.values();
    for (manifest.dependencies.keys(), 0..) |name, i| {
        const dep = deps_list[i];

        const sub_prefix = try std.fmt.allocPrint(arena, "{s}{s}.", .{ name_prefix, name });
        const fqn = sub_prefix[0 .. sub_prefix.len - 1];

        const sub_pkg = try fetchAndUnpack(
            thread_pool,
            http_client,
            global_cache_directory,
            dep,
            report,
            build_roots_source,
            fqn,
            all_modules,
        );

        try pkg.fetchAndAddDependencies(
            arena,
            thread_pool,
            http_client,
            sub_pkg.root_src_directory,
            global_cache_directory,
            local_cache_directory,
            dependencies_source,
            build_roots_source,
            sub_prefix,
            color,
            all_modules,
        );

        try add(pkg, gpa, fqn, sub_pkg);

        try dependencies_source.writer().print("    pub const {s} = @import(\"{}\");\n", .{
            std.zig.fmtId(fqn), std.zig.fmtEscapes(fqn),
        });
    }

    if (any_error) return error.InvalidBuildManifestFile;
}

pub fn createFilePkg(
    gpa: Allocator,
    cache_directory: Compilation.Directory,
    basename: []const u8,
    contents: []const u8,
) !*Package {
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ fs.path.sep_str ++ Manifest.hex64(rand_int);
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

const Report = struct {
    ast: *const std.zig.Ast,
    directory: Compilation.Directory,
    color: main.Color,
    arena: Allocator,

    fn fail(
        report: Report,
        tok: std.zig.Ast.TokenIndex,
        comptime fmt_string: []const u8,
        fmt_args: anytype,
    ) error{ PackageFetchFailed, OutOfMemory } {
        return failWithNotes(report, &.{}, tok, fmt_string, fmt_args);
    }

    fn failWithNotes(
        report: Report,
        notes: []const Compilation.AllErrors.Message,
        tok: std.zig.Ast.TokenIndex,
        comptime fmt_string: []const u8,
        fmt_args: anytype,
    ) error{ PackageFetchFailed, OutOfMemory } {
        const ttyconf: std.debug.TTY.Config = switch (report.color) {
            .auto => std.debug.detectTTYConfig(std.io.getStdErr()),
            .on => .escape_codes,
            .off => .no_color,
        };
        const file_path = try report.directory.join(report.arena, &.{Manifest.basename});
        renderErrorMessage(report.ast.*, file_path, ttyconf, .{
            .tok = tok,
            .off = 0,
            .msg = try std.fmt.allocPrint(report.arena, fmt_string, fmt_args),
        }, notes);
        return error.PackageFetchFailed;
    }

    fn renderErrorMessage(
        ast: std.zig.Ast,
        file_path: []const u8,
        ttyconf: std.debug.TTY.Config,
        msg: Manifest.ErrorMessage,
        notes: []const Compilation.AllErrors.Message,
    ) void {
        const token_starts = ast.tokens.items(.start);
        const start_loc = ast.tokenLocation(0, msg.tok);
        Compilation.AllErrors.Message.renderToStdErr(.{ .src = .{
            .msg = msg.msg,
            .src_path = file_path,
            .line = @intCast(u32, start_loc.line),
            .column = @intCast(u32, start_loc.column),
            .span = .{
                .start = token_starts[msg.tok],
                .end = @intCast(u32, token_starts[msg.tok] + ast.tokenSlice(msg.tok).len),
                .main = token_starts[msg.tok] + msg.off,
            },
            .source_line = ast.source[start_loc.line_start..start_loc.line_end],
            .notes = notes,
        } }, ttyconf);
    }
};

const hex_multihash_len = 2 * Manifest.multihash_len;
const MultiHashHexDigest = [hex_multihash_len]u8;
/// This is to avoid creating multiple modules for the same build.zig file.
pub const AllModules = std.AutoHashMapUnmanaged(MultiHashHexDigest, *Package);

fn fetchAndUnpack(
    thread_pool: *ThreadPool,
    http_client: *std.http.Client,
    global_cache_directory: Compilation.Directory,
    dep: Manifest.Dependency,
    report: Report,
    build_roots_source: *std.ArrayList(u8),
    fqn: []const u8,
    all_modules: *AllModules,
) !*Package {
    const gpa = http_client.allocator;
    const s = fs.path.sep_str;

    // Check if the expected_hash is already present in the global package
    // cache, and thereby avoid both fetching and unpacking.
    if (dep.hash) |h| cached: {
        const hex_digest = h[0..hex_multihash_len];
        const pkg_dir_sub_path = "p" ++ s ++ hex_digest;

        const build_root = try global_cache_directory.join(gpa, &.{pkg_dir_sub_path});
        errdefer gpa.free(build_root);

        try build_roots_source.writer().print("    pub const {s} = \"{}\";\n", .{
            std.zig.fmtId(fqn), std.zig.fmtEscapes(build_root),
        });

        // The compiler has a rule that a file must not be included in multiple modules,
        // so we must detect if a module has been created for this package and reuse it.
        const gop = try all_modules.getOrPut(gpa, hex_digest.*);
        if (gop.found_existing) {
            gpa.free(build_root);
            return gop.value_ptr.*;
        }

        var pkg_dir = global_cache_directory.handle.openDir(pkg_dir_sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :cached,
            else => |e| return e,
        };
        errdefer pkg_dir.close();

        const ptr = try gpa.create(Package);
        errdefer gpa.destroy(ptr);

        const owned_src_path = try gpa.dupe(u8, build_zig_basename);
        errdefer gpa.free(owned_src_path);

        ptr.* = .{
            .root_src_directory = .{
                .path = build_root,
                .handle = pkg_dir,
            },
            .root_src_directory_owned = true,
            .root_src_path = owned_src_path,
        };

        gop.value_ptr.* = ptr;
        return ptr;
    }

    const uri = try std.Uri.parse(dep.url);

    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ s ++ Manifest.hex64(rand_int);

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
            try unpackTarball(gpa, &req, tmp_directory.handle, std.compress.gzip);
        } else if (mem.endsWith(u8, uri.path, ".tar.xz")) {
            // I have not checked what buffer sizes the xz decompression implementation uses
            // by default, so the same logic applies for buffering the reader as for gzip.
            try unpackTarball(gpa, &req, tmp_directory.handle, std.compress.xz);
        } else {
            return report.fail(dep.url_tok, "unknown file extension for path '{s}'", .{
                uri.path,
            });
        }

        // TODO: delete files not included in the package prior to computing the package hash.
        // for example, if the ini file has directives to include/not include certain files,
        // apply those rules directly to the filesystem right here. This ensures that files
        // not protected by the hash are not present on the file system.

        // TODO: raise an error for files that have illegal paths on some operating systems.
        // For example, on Linux a path with a backslash should raise an error here.
        // Of course, if the ignore rules above omit the file from the package, then everything
        // is fine and no error should be raised.

        break :a try computePackageHash(thread_pool, .{ .dir = tmp_directory.handle });
    };

    const pkg_dir_sub_path = "p" ++ s ++ Manifest.hexDigest(actual_hash);
    try renameTmpIntoCache(global_cache_directory.handle, tmp_dir_sub_path, pkg_dir_sub_path);

    const actual_hex = Manifest.hexDigest(actual_hash);
    if (dep.hash) |h| {
        if (!mem.eql(u8, h, &actual_hex)) {
            return report.fail(dep.hash_tok, "hash mismatch: expected: {s}, found: {s}", .{
                h, actual_hex,
            });
        }
    } else {
        const notes: [1]Compilation.AllErrors.Message = .{.{ .plain = .{
            .msg = try std.fmt.allocPrint(report.arena, "expected .hash = \"{s}\",", .{&actual_hex}),
        } }};
        return report.failWithNotes(&notes, dep.url_tok, "url field is missing corresponding hash field", .{});
    }

    const build_root = try global_cache_directory.join(gpa, &.{pkg_dir_sub_path});
    defer gpa.free(build_root);

    try build_roots_source.writer().print("    pub const {s} = \"{}\";\n", .{
        std.zig.fmtId(fqn), std.zig.fmtEscapes(build_root),
    });

    return createWithDir(gpa, global_cache_directory, pkg_dir_sub_path, build_zig_basename);
}

fn unpackTarball(
    gpa: Allocator,
    req: *std.http.Client.Request,
    out_dir: fs.Dir,
    comptime compression: type,
) !void {
    var br = std.io.bufferedReaderSize(std.crypto.tls.max_ciphertext_record_len, req.reader());

    var decompress = try compression.decompress(gpa, br.reader());
    defer decompress.deinit();

    try std.tar.pipeToFileSystem(out_dir, decompress.reader(), .{
        .strip_components = 1,
        // TODO: we would like to set this to executable_bit_only, but two
        // things need to happen before that:
        // 1. the tar implementation needs to support it
        // 2. the hashing algorithm here needs to support detecting the is_executable
        //    bit on Windows from the ACLs (see the isExecutable function).
        .mode_mode = .ignore,
    });
}

const HashedFile = struct {
    fs_path: []const u8,
    normalized_path: []const u8,
    hash: [Manifest.Hash.digest_length]u8,
    failure: Error!void,

    const Error = fs.File.OpenError || fs.File.ReadError || fs.File.StatError;

    fn lessThan(context: void, lhs: *const HashedFile, rhs: *const HashedFile) bool {
        _ = context;
        return mem.lessThan(u8, lhs.normalized_path, rhs.normalized_path);
    }
};

fn computePackageHash(
    thread_pool: *ThreadPool,
    pkg_dir: fs.IterableDir,
) ![Manifest.Hash.digest_length]u8 {
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
            const fs_path = try arena.dupe(u8, entry.path);
            hashed_file.* = .{
                .fs_path = fs_path,
                .normalized_path = try normalizePath(arena, fs_path),
                .hash = undefined, // to be populated by the worker
                .failure = undefined, // to be populated by the worker
            };
            wait_group.start();
            try thread_pool.spawn(workerHashFile, .{ pkg_dir.dir, hashed_file, &wait_group });

            try all_files.append(hashed_file);
        }
    }

    std.sort.sort(*HashedFile, all_files.items, {}, HashedFile.lessThan);

    var hasher = Manifest.Hash.init(.{});
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
    var file = try dir.openFile(hashed_file.fs_path, .{});
    defer file.close();
    var hasher = Manifest.Hash.init(.{});
    hasher.update(hashed_file.normalized_path);
    hasher.update(&.{ 0, @boolToInt(try isExecutable(file)) });
    while (true) {
        const bytes_read = try file.read(&buf);
        if (bytes_read == 0) break;
        hasher.update(buf[0..bytes_read]);
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
