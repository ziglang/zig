//! Represents one independent job whose responsibility is to:
//!
//! 1. Check the global zig package cache to see if the hash already exists.
//!    If so, load, parse, and validate the build.zig.zon file therein, and
//!    goto step 8. Likewise if the location is a relative path, treat this
//!    the same as a cache hit. Otherwise, proceed.
//! 2. Fetch and unpack a URL into a temporary directory.
//! 3. Load, parse, and validate the build.zig.zon file therein. It is allowed
//!    for the file to be missing, in which case this fetched package is considered
//!    to be a "naked" package.
//! 4. Apply inclusion rules of the build.zig.zon to the temporary directory by
//!    deleting excluded files. If any files had errors for files that were
//!    ultimately excluded, those errors should be ignored, such as failure to
//!    create symlinks that weren't supposed to be included anyway.
//! 5. Compute the package hash based on the remaining files in the temporary
//!    directory.
//! 6. Rename the temporary directory into the global zig package cache
//!    directory. If the hash already exists, delete the temporary directory and
//!    leave the zig package cache directory untouched as it may be in use by the
//!    system. This is done even if the hash is invalid, in case the package with
//!    the different hash is used in the future.
//! 7. Validate the computed hash against the expected hash. If invalid,
//!    this job is done.
//! 8. Spawn a new fetch job for each dependency in the manifest file. Use
//!    a mutex and a hash map so that redundant jobs do not get queued up.
//!
//! All of this must be done with only referring to the state inside this struct
//! because this work will be done in a dedicated thread.

arena: std.heap.ArenaAllocator,
location: Location,
location_tok: std.zig.Ast.TokenIndex,
hash_tok: std.zig.Ast.TokenIndex,
name_tok: std.zig.Ast.TokenIndex,
lazy_status: LazyStatus,
parent_package_root: Package.Path,
parent_manifest_ast: ?*const std.zig.Ast,
prog_node: *std.Progress.Node,
job_queue: *JobQueue,
/// If true, don't add an error for a missing hash. This flag is not passed
/// down to recursive dependencies. It's intended to be used only be the CLI.
omit_missing_hash_error: bool,
/// If true, don't fail when a manifest file is missing the `paths` field,
/// which specifies inclusion rules. This is intended to be true for the first
/// fetch task and false for the recursive dependencies.
allow_missing_paths_field: bool,

// Above this are fields provided as inputs to `run`.
// Below this are fields populated by `run`.

/// This will either be relative to `global_cache`, or to the build root of
/// the root package.
package_root: Package.Path,
error_bundle: ErrorBundle.Wip,
manifest: ?Manifest,
manifest_ast: std.zig.Ast,
actual_hash: Manifest.Digest,
/// Fetch logic notices whether a package has a build.zig file and sets this flag.
has_build_zig: bool,
/// Indicates whether the task aborted due to an out-of-memory condition.
oom_flag: bool,

// This field is used by the CLI only, untouched by this file.

/// The module for this `Fetch` tasks's package, which exposes `build.zig` as
/// the root source file.
module: ?*Package.Module,

pub const LazyStatus = enum {
    /// Not lazy.
    eager,
    /// Lazy, found.
    available,
    /// Lazy, not found.
    unavailable,
};

/// Contains shared state among all `Fetch` tasks.
pub const JobQueue = struct {
    mutex: std.Thread.Mutex = .{},
    /// It's an array hash map so that it can be sorted before rendering the
    /// dependencies.zig source file.
    /// Protected by `mutex`.
    table: Table = .{},
    /// `table` may be missing some tasks such as ones that failed, so this
    /// field contains references to all of them.
    /// Protected by `mutex`.
    all_fetches: std.ArrayListUnmanaged(*Fetch) = .{},

    http_client: *std.http.Client,
    thread_pool: *ThreadPool,
    wait_group: WaitGroup = .{},
    global_cache: Cache.Directory,
    /// If true then, no fetching occurs, and:
    /// * The `global_cache` directory is assumed to be the direct parent
    ///   directory of on-disk packages rather than having the "p/" directory
    ///   prefix inside of it.
    /// * An error occurs if any non-lazy packages are not already present in
    ///   the package cache directory.
    /// * Missing hash field causes an error, and no fetching occurs so it does
    ///   not print the correct hash like usual.
    read_only: bool,
    recursive: bool,
    /// Dumps hash information to stdout which can be used to troubleshoot why
    /// two hashes of the same package do not match.
    /// If this is true, `recursive` must be false.
    debug_hash: bool,
    work_around_btrfs_bug: bool,
    /// Set of hashes that will be additionally fetched even if they are marked
    /// as lazy.
    unlazy_set: UnlazySet = .{},

    pub const Table = std.AutoArrayHashMapUnmanaged(Manifest.MultiHashHexDigest, *Fetch);
    pub const UnlazySet = std.AutoArrayHashMapUnmanaged(Manifest.MultiHashHexDigest, void);

    pub fn deinit(jq: *JobQueue) void {
        if (jq.all_fetches.items.len == 0) return;
        const gpa = jq.all_fetches.items[0].arena.child_allocator;
        jq.table.deinit(gpa);
        // These must be deinitialized in reverse order because subsequent
        // `Fetch` instances are allocated in prior ones' arenas.
        // Sorry, I know it's a bit weird, but it slightly simplifies the
        // critical section.
        while (jq.all_fetches.popOrNull()) |f| f.deinit();
        jq.all_fetches.deinit(gpa);
        jq.* = undefined;
    }

    /// Dumps all subsequent error bundles into the first one.
    pub fn consolidateErrors(jq: *JobQueue) !void {
        const root = &jq.all_fetches.items[0].error_bundle;
        const gpa = root.gpa;
        for (jq.all_fetches.items[1..]) |fetch| {
            if (fetch.error_bundle.root_list.items.len > 0) {
                var bundle = try fetch.error_bundle.toOwnedBundle("");
                defer bundle.deinit(gpa);
                try root.addBundleAsRoots(bundle);
            }
        }
    }

    /// Creates the dependencies.zig source code for the build runner to obtain
    /// via `@import("@dependencies")`.
    pub fn createDependenciesSource(jq: *JobQueue, buf: *std.ArrayList(u8)) Allocator.Error!void {
        const keys = jq.table.keys();

        assert(keys.len != 0); // caller should have added the first one
        if (keys.len == 1) {
            // This is the first one. It must have no dependencies.
            return createEmptyDependenciesSource(buf);
        }

        try buf.appendSlice("pub const packages = struct {\n");

        // Ensure the generated .zig file is deterministic.
        jq.table.sortUnstable(@as(struct {
            keys: []const Manifest.MultiHashHexDigest,
            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                return std.mem.lessThan(u8, &ctx.keys[a_index], &ctx.keys[b_index]);
            }
        }, .{ .keys = keys }));

        for (keys, jq.table.values()) |hash, fetch| {
            if (fetch == jq.all_fetches.items[0]) {
                // The first one is a dummy package for the current project.
                continue;
            }

            try buf.writer().print(
                \\    pub const {} = struct {{
                \\
            , .{std.zig.fmtId(&hash)});

            lazy: {
                switch (fetch.lazy_status) {
                    .eager => break :lazy,
                    .available => {
                        try buf.appendSlice(
                            \\        pub const available = true;
                            \\
                        );
                        break :lazy;
                    },
                    .unavailable => {
                        try buf.appendSlice(
                            \\        pub const available = false;
                            \\    };
                            \\
                        );
                        continue;
                    },
                }
            }

            try buf.writer().print(
                \\        pub const build_root = "{q}";
                \\
            , .{fetch.package_root});

            if (fetch.has_build_zig) {
                try buf.writer().print(
                    \\        pub const build_zig = @import("{}");
                    \\
                , .{std.zig.fmtEscapes(&hash)});
            }

            if (fetch.manifest) |*manifest| {
                try buf.appendSlice(
                    \\        pub const deps: []const struct { []const u8, []const u8 } = &.{
                    \\
                );
                for (manifest.dependencies.keys(), manifest.dependencies.values()) |name, dep| {
                    const h = depDigest(fetch.package_root, jq.global_cache, dep) orelse continue;
                    try buf.writer().print(
                        "            .{{ \"{}\", \"{}\" }},\n",
                        .{ std.zig.fmtEscapes(name), std.zig.fmtEscapes(&h) },
                    );
                }

                try buf.appendSlice(
                    \\        };
                    \\    };
                    \\
                );
            } else {
                try buf.appendSlice(
                    \\        pub const deps: []const struct { []const u8, []const u8 } = &.{};
                    \\    };
                    \\
                );
            }
        }

        try buf.appendSlice(
            \\};
            \\
            \\pub const root_deps: []const struct { []const u8, []const u8 } = &.{
            \\
        );

        const root_fetch = jq.all_fetches.items[0];
        const root_manifest = &root_fetch.manifest.?;

        for (root_manifest.dependencies.keys(), root_manifest.dependencies.values()) |name, dep| {
            const h = depDigest(root_fetch.package_root, jq.global_cache, dep) orelse continue;
            try buf.writer().print(
                "    .{{ \"{}\", \"{}\" }},\n",
                .{ std.zig.fmtEscapes(name), std.zig.fmtEscapes(&h) },
            );
        }
        try buf.appendSlice("};\n");
    }

    pub fn createEmptyDependenciesSource(buf: *std.ArrayList(u8)) Allocator.Error!void {
        try buf.appendSlice(
            \\pub const packages = struct {};
            \\pub const root_deps: []const struct { []const u8, []const u8 } = &.{};
            \\
        );
    }
};

pub const Location = union(enum) {
    remote: Remote,
    /// A directory found inside the parent package.
    relative_path: Package.Path,
    /// Recursive Fetch tasks will never use this Location, but it may be
    /// passed in by the CLI. Indicates the file contents here should be copied
    /// into the global package cache. It may be a file relative to the cwd or
    /// absolute, in which case it should be treated exactly like a `file://`
    /// URL, or a directory, in which case it should be treated as an
    /// already-unpacked directory (but still needs to be copied into the
    /// global package cache and have inclusion rules applied).
    path_or_url: []const u8,

    pub const Remote = struct {
        url: []const u8,
        /// If this is null it means the user omitted the hash field from a dependency.
        /// It will be an error but the logic should still fetch and print the discovered hash.
        hash: ?Manifest.MultiHashHexDigest,
    };
};

pub const RunError = error{
    OutOfMemory,
    /// This error code is intended to be handled by inspecting the
    /// `error_bundle` field.
    FetchFailed,
};

pub fn run(f: *Fetch) RunError!void {
    const eb = &f.error_bundle;
    const arena = f.arena.allocator();
    const gpa = f.arena.child_allocator;
    const cache_root = f.job_queue.global_cache;

    try eb.init(gpa);

    // Check the global zig package cache to see if the hash already exists. If
    // so, load, parse, and validate the build.zig.zon file therein, and skip
    // ahead to queuing up jobs for dependencies. Likewise if the location is a
    // relative path, treat this the same as a cache hit. Otherwise, proceed.

    const remote = switch (f.location) {
        .relative_path => |pkg_root| {
            if (fs.path.isAbsolute(pkg_root.sub_path)) return f.fail(
                f.location_tok,
                try eb.addString("expected path relative to build root; found absolute path"),
            );
            if (f.hash_tok != 0) return f.fail(
                f.hash_tok,
                try eb.addString("path-based dependencies are not hashed"),
            );
            // Packages fetched by URL may not use relative paths to escape outside the
            // fetched package directory from within the package cache.
            if (pkg_root.root_dir.eql(cache_root)) {
                // `parent_package_root.sub_path` contains a path like this:
                // "p/$hash", or
                // "p/$hash/foo", with possibly more directories after "foo".
                // We want to fail unless the resolved relative path has a
                // prefix of "p/$hash/".
                const digest_len = @typeInfo(Manifest.MultiHashHexDigest).Array.len;
                const prefix_len: usize = if (f.job_queue.read_only) 0 else "p/".len;
                const expected_prefix = f.parent_package_root.sub_path[0 .. prefix_len + digest_len];
                if (!std.mem.startsWith(u8, pkg_root.sub_path, expected_prefix)) {
                    return f.fail(
                        f.location_tok,
                        try eb.printString("dependency path outside project: '{}'", .{pkg_root}),
                    );
                }
            }
            f.package_root = pkg_root;
            try loadManifest(f, pkg_root);
            if (!f.has_build_zig) try checkBuildFileExistence(f);
            if (!f.job_queue.recursive) return;
            return queueJobsForDeps(f);
        },
        .remote => |remote| remote,
        .path_or_url => |path_or_url| {
            if (fs.cwd().openDir(path_or_url, .{ .iterate = true })) |dir| {
                var resource: Resource = .{ .dir = dir };
                return runResource(f, path_or_url, &resource, null);
            } else |dir_err| {
                const file_err = if (dir_err == error.NotDir) e: {
                    if (fs.cwd().openFile(path_or_url, .{})) |file| {
                        var resource: Resource = .{ .file = file };
                        return runResource(f, path_or_url, &resource, null);
                    } else |err| break :e err;
                } else dir_err;

                const uri = std.Uri.parse(path_or_url) catch |uri_err| {
                    return f.fail(0, try eb.printString(
                        "'{s}' could not be recognized as a file path ({s}) or an URL ({s})",
                        .{ path_or_url, @errorName(file_err), @errorName(uri_err) },
                    ));
                };
                var resource = try f.initResource(uri);
                return runResource(f, uri.path, &resource, null);
            }
        },
    };

    const s = fs.path.sep_str;
    if (remote.hash) |expected_hash| {
        const prefixed_pkg_sub_path = "p" ++ s ++ expected_hash;
        const prefix_len: usize = if (f.job_queue.read_only) "p/".len else 0;
        const pkg_sub_path = prefixed_pkg_sub_path[prefix_len..];
        if (cache_root.handle.access(pkg_sub_path, .{})) |_| {
            assert(f.lazy_status != .unavailable);
            f.package_root = .{
                .root_dir = cache_root,
                .sub_path = try arena.dupe(u8, pkg_sub_path),
            };
            try loadManifest(f, f.package_root);
            try checkBuildFileExistence(f);
            if (!f.job_queue.recursive) return;
            return queueJobsForDeps(f);
        } else |err| switch (err) {
            error.FileNotFound => {
                switch (f.lazy_status) {
                    .eager => {},
                    .available => if (!f.job_queue.unlazy_set.contains(expected_hash)) {
                        f.lazy_status = .unavailable;
                        return;
                    },
                    .unavailable => unreachable,
                }
                if (f.job_queue.read_only) return f.fail(
                    f.name_tok,
                    try eb.printString("package not found at '{}{s}'", .{
                        cache_root, pkg_sub_path,
                    }),
                );
            },
            else => |e| {
                try eb.addRootErrorMessage(.{
                    .msg = try eb.printString("unable to open global package cache directory '{}{s}': {s}", .{
                        cache_root, pkg_sub_path, @errorName(e),
                    }),
                });
                return error.FetchFailed;
            },
        }
    } else {
        try eb.addRootErrorMessage(.{
            .msg = try eb.addString("dependency is missing hash field"),
            .src_loc = try f.srcLoc(f.location_tok),
        });
        return error.FetchFailed;
    }

    // Fetch and unpack the remote into a temporary directory.

    const uri = std.Uri.parse(remote.url) catch |err| return f.fail(
        f.location_tok,
        try eb.printString("invalid URI: {s}", .{@errorName(err)}),
    );
    var resource = try f.initResource(uri);
    return runResource(f, uri.path, &resource, remote.hash);
}

pub fn deinit(f: *Fetch) void {
    f.error_bundle.deinit();
    f.arena.deinit();
}

/// Consumes `resource`, even if an error is returned.
fn runResource(
    f: *Fetch,
    uri_path: []const u8,
    resource: *Resource,
    remote_hash: ?Manifest.MultiHashHexDigest,
) RunError!void {
    defer resource.deinit();
    const arena = f.arena.allocator();
    const eb = &f.error_bundle;
    const s = fs.path.sep_str;
    const cache_root = f.job_queue.global_cache;
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ s ++ Manifest.hex64(rand_int);

    {
        const tmp_directory_path = try cache_root.join(arena, &.{tmp_dir_sub_path});
        var tmp_directory: Cache.Directory = .{
            .path = tmp_directory_path,
            .handle = handle: {
                const dir = cache_root.handle.makeOpenPath(tmp_dir_sub_path, .{
                    .iterate = true,
                }) catch |err| {
                    try eb.addRootErrorMessage(.{
                        .msg = try eb.printString("unable to create temporary directory '{s}': {s}", .{
                            tmp_directory_path, @errorName(err),
                        }),
                    });
                    return error.FetchFailed;
                };
                break :handle dir;
            },
        };
        defer tmp_directory.handle.close();

        try unpackResource(f, resource, uri_path, tmp_directory);

        // Load, parse, and validate the unpacked build.zig.zon file. It is allowed
        // for the file to be missing, in which case this fetched package is
        // considered to be a "naked" package.
        try loadManifest(f, .{ .root_dir = tmp_directory });

        // Apply the manifest's inclusion rules to the temporary directory by
        // deleting excluded files. If any error occurred for files that were
        // ultimately excluded, those errors should be ignored, such as failure to
        // create symlinks that weren't supposed to be included anyway.

        // Empty directories have already been omitted by `unpackResource`.

        const filter: Filter = .{
            .include_paths = if (f.manifest) |m| m.paths else .{},
        };

        // Compute the package hash based on the remaining files in the temporary
        // directory.

        if (builtin.os.tag == .linux and f.job_queue.work_around_btrfs_bug) {
            // https://github.com/ziglang/zig/issues/17095
            tmp_directory.handle.close();
            tmp_directory.handle = cache_root.handle.makeOpenPath(tmp_dir_sub_path, .{
                .iterate = true,
            }) catch @panic("btrfs workaround failed");
        }

        f.actual_hash = try computeHash(f, tmp_directory, filter);
    }

    // Rename the temporary directory into the global zig package cache
    // directory. If the hash already exists, delete the temporary directory
    // and leave the zig package cache directory untouched as it may be in use
    // by the system. This is done even if the hash is invalid, in case the
    // package with the different hash is used in the future.

    f.package_root = .{
        .root_dir = cache_root,
        .sub_path = try arena.dupe(u8, "p" ++ s ++ Manifest.hexDigest(f.actual_hash)),
    };
    renameTmpIntoCache(cache_root.handle, tmp_dir_sub_path, f.package_root.sub_path) catch |err| {
        const src = try cache_root.join(arena, &.{tmp_dir_sub_path});
        const dest = try cache_root.join(arena, &.{f.package_root.sub_path});
        try eb.addRootErrorMessage(.{ .msg = try eb.printString(
            "unable to rename temporary directory '{s}' into package cache directory '{s}': {s}",
            .{ src, dest, @errorName(err) },
        ) });
        return error.FetchFailed;
    };

    // Validate the computed hash against the expected hash. If invalid, this
    // job is done.

    const actual_hex = Manifest.hexDigest(f.actual_hash);
    if (remote_hash) |declared_hash| {
        if (!std.mem.eql(u8, &declared_hash, &actual_hex)) {
            return f.fail(f.hash_tok, try eb.printString(
                "hash mismatch: manifest declares {s} but the fetched package has {s}",
                .{ declared_hash, actual_hex },
            ));
        }
    } else if (!f.omit_missing_hash_error) {
        const notes_len = 1;
        try eb.addRootErrorMessage(.{
            .msg = try eb.addString("dependency is missing hash field"),
            .src_loc = try f.srcLoc(f.location_tok),
            .notes_len = notes_len,
        });
        const notes_start = try eb.reserveNotes(notes_len);
        eb.extra.items[notes_start] = @intFromEnum(try eb.addErrorMessage(.{
            .msg = try eb.printString("expected .hash = \"{s}\",", .{&actual_hex}),
        }));
        return error.FetchFailed;
    }

    // Spawn a new fetch job for each dependency in the manifest file. Use
    // a mutex and a hash map so that redundant jobs do not get queued up.
    if (!f.job_queue.recursive) return;
    return queueJobsForDeps(f);
}

/// `computeHash` gets a free check for the existence of `build.zig`, but when
/// not computing a hash, we need to do a syscall to check for it.
fn checkBuildFileExistence(f: *Fetch) RunError!void {
    const eb = &f.error_bundle;
    if (f.package_root.access(Package.build_zig_basename, .{})) |_| {
        f.has_build_zig = true;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => |e| {
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("unable to access '{}{s}': {s}", .{
                    f.package_root, Package.build_zig_basename, @errorName(e),
                }),
            });
            return error.FetchFailed;
        },
    }
}

/// This function populates `f.manifest` or leaves it `null`.
fn loadManifest(f: *Fetch, pkg_root: Package.Path) RunError!void {
    const eb = &f.error_bundle;
    const arena = f.arena.allocator();
    const manifest_bytes = pkg_root.root_dir.handle.readFileAllocOptions(
        arena,
        try fs.path.join(arena, &.{ pkg_root.sub_path, Manifest.basename }),
        Manifest.max_bytes,
        null,
        1,
        0,
    ) catch |err| switch (err) {
        error.FileNotFound => return,
        else => |e| {
            const file_path = try pkg_root.join(arena, Manifest.basename);
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("unable to load package manifest '{}': {s}", .{
                    file_path, @errorName(e),
                }),
            });
            return error.FetchFailed;
        },
    };

    const ast = &f.manifest_ast;
    ast.* = try std.zig.Ast.parse(arena, manifest_bytes, .zon);

    if (ast.errors.len > 0) {
        const file_path = try std.fmt.allocPrint(arena, "{}" ++ Manifest.basename, .{pkg_root});
        try main.putAstErrorsIntoBundle(arena, ast.*, file_path, eb);
        return error.FetchFailed;
    }

    f.manifest = try Manifest.parse(arena, ast.*, .{
        .allow_missing_paths_field = f.allow_missing_paths_field,
    });
    const manifest = &f.manifest.?;

    if (manifest.errors.len > 0) {
        const src_path = try eb.printString("{}{s}", .{ pkg_root, Manifest.basename });
        try manifest.copyErrorsIntoBundle(ast.*, src_path, eb);
        return error.FetchFailed;
    }
}

fn queueJobsForDeps(f: *Fetch) RunError!void {
    assert(f.job_queue.recursive);

    // If the package does not have a build.zig.zon file then there are no dependencies.
    const manifest = f.manifest orelse return;

    const new_fetches, const prog_names = nf: {
        const parent_arena = f.arena.allocator();
        const gpa = f.arena.child_allocator;
        const cache_root = f.job_queue.global_cache;
        const dep_names = manifest.dependencies.keys();
        const deps = manifest.dependencies.values();
        // Grab the new tasks into a temporary buffer so we can unlock that mutex
        // as fast as possible.
        // This overallocates any fetches that get skipped by the `continue` in the
        // loop below.
        const new_fetches = try parent_arena.alloc(Fetch, deps.len);
        const prog_names = try parent_arena.alloc([]const u8, deps.len);
        var new_fetch_index: usize = 0;

        f.job_queue.mutex.lock();
        defer f.job_queue.mutex.unlock();

        try f.job_queue.all_fetches.ensureUnusedCapacity(gpa, new_fetches.len);
        try f.job_queue.table.ensureUnusedCapacity(gpa, @intCast(new_fetches.len));

        // There are four cases here:
        // * Correct hash is provided by manifest.
        //   - Hash map already has the entry, no need to add it again.
        // * Incorrect hash is provided by manifest.
        //   - Hash mismatch error emitted; `queueJobsForDeps` is not called.
        // * Hash is not provided by manifest.
        //   - Hash missing error emitted; `queueJobsForDeps` is not called.
        // * path-based location is used without a hash.
        //   - Hash is added to the table based on the path alone before
        //     calling run(); no need to add it again.

        for (dep_names, deps) |dep_name, dep| {
            const new_fetch = &new_fetches[new_fetch_index];
            const location: Location = switch (dep.location) {
                .url => |url| .{ .remote = .{
                    .url = url,
                    .hash = h: {
                        const h = dep.hash orelse break :h null;
                        const digest_len = @typeInfo(Manifest.MultiHashHexDigest).Array.len;
                        const multihash_digest = h[0..digest_len].*;
                        const gop = f.job_queue.table.getOrPutAssumeCapacity(multihash_digest);
                        if (gop.found_existing) continue;
                        gop.value_ptr.* = new_fetch;
                        break :h multihash_digest;
                    },
                } },
                .path => |rel_path| l: {
                    // This might produce an invalid path, which is checked for
                    // at the beginning of run().
                    const new_root = try f.package_root.resolvePosix(parent_arena, rel_path);
                    const multihash_digest = relativePathDigest(new_root, cache_root);
                    const gop = f.job_queue.table.getOrPutAssumeCapacity(multihash_digest);
                    if (gop.found_existing) continue;
                    gop.value_ptr.* = new_fetch;
                    break :l .{ .relative_path = new_root };
                },
            };
            prog_names[new_fetch_index] = dep_name;
            new_fetch_index += 1;
            f.job_queue.all_fetches.appendAssumeCapacity(new_fetch);
            new_fetch.* = .{
                .arena = std.heap.ArenaAllocator.init(gpa),
                .location = location,
                .location_tok = dep.location_tok,
                .hash_tok = dep.hash_tok,
                .name_tok = dep.name_tok,
                .lazy_status = if (dep.lazy) .available else .eager,
                .parent_package_root = f.package_root,
                .parent_manifest_ast = &f.manifest_ast,
                .prog_node = f.prog_node,
                .job_queue = f.job_queue,
                .omit_missing_hash_error = false,
                .allow_missing_paths_field = true,

                .package_root = undefined,
                .error_bundle = undefined,
                .manifest = null,
                .manifest_ast = undefined,
                .actual_hash = undefined,
                .has_build_zig = false,
                .oom_flag = false,

                .module = null,
            };
        }

        // job_queue mutex is locked so this is OK.
        f.prog_node.unprotected_estimated_total_items += new_fetch_index;

        break :nf .{ new_fetches[0..new_fetch_index], prog_names[0..new_fetch_index] };
    };

    // Now it's time to give tasks to the thread pool.
    const thread_pool = f.job_queue.thread_pool;

    for (new_fetches, prog_names) |*new_fetch, prog_name| {
        f.job_queue.wait_group.start();
        thread_pool.spawn(workerRun, .{ new_fetch, prog_name }) catch |err| switch (err) {
            error.OutOfMemory => {
                new_fetch.oom_flag = true;
                f.job_queue.wait_group.finish();
                continue;
            },
        };
    }
}

pub fn relativePathDigest(
    pkg_root: Package.Path,
    cache_root: Cache.Directory,
) Manifest.MultiHashHexDigest {
    var hasher = Manifest.Hash.init(.{});
    // This hash is a tuple of:
    // * whether it relative to the global cache directory or to the root package
    // * the relative file path from there to the build root of the package
    hasher.update(if (pkg_root.root_dir.eql(cache_root))
        &package_hash_prefix_cached
    else
        &package_hash_prefix_project);
    hasher.update(pkg_root.sub_path);
    return Manifest.hexDigest(hasher.finalResult());
}

pub fn workerRun(f: *Fetch, prog_name: []const u8) void {
    defer f.job_queue.wait_group.finish();

    var prog_node = f.prog_node.start(prog_name, 0);
    defer prog_node.end();
    prog_node.activate();

    run(f) catch |err| switch (err) {
        error.OutOfMemory => f.oom_flag = true,
        error.FetchFailed => {
            // Nothing to do because the errors are already reported in `error_bundle`,
            // and a reference is kept to the `Fetch` task inside `all_fetches`.
        },
    };
}

fn srcLoc(
    f: *Fetch,
    tok: std.zig.Ast.TokenIndex,
) Allocator.Error!ErrorBundle.SourceLocationIndex {
    const ast = f.parent_manifest_ast orelse return .none;
    const eb = &f.error_bundle;
    const token_starts = ast.tokens.items(.start);
    const start_loc = ast.tokenLocation(0, tok);
    const src_path = try eb.printString("{}" ++ Manifest.basename, .{f.parent_package_root});
    const msg_off = 0;
    return eb.addSourceLocation(.{
        .src_path = src_path,
        .span_start = token_starts[tok],
        .span_end = @intCast(token_starts[tok] + ast.tokenSlice(tok).len),
        .span_main = token_starts[tok] + msg_off,
        .line = @intCast(start_loc.line),
        .column = @intCast(start_loc.column),
        .source_line = try eb.addString(ast.source[start_loc.line_start..start_loc.line_end]),
    });
}

fn fail(f: *Fetch, msg_tok: std.zig.Ast.TokenIndex, msg_str: u32) RunError {
    const eb = &f.error_bundle;
    try eb.addRootErrorMessage(.{
        .msg = msg_str,
        .src_loc = try f.srcLoc(msg_tok),
    });
    return error.FetchFailed;
}

const Resource = union(enum) {
    file: fs.File,
    http_request: std.http.Client.Request,
    git: Git,
    dir: fs.Dir,

    const Git = struct {
        fetch_stream: git.Session.FetchStream,
        want_oid: [git.oid_length]u8,
    };

    fn deinit(resource: *Resource) void {
        switch (resource.*) {
            .file => |*file| file.close(),
            .http_request => |*req| req.deinit(),
            .git => |*git_resource| git_resource.fetch_stream.deinit(),
            .dir => |*dir| dir.close(),
        }
        resource.* = undefined;
    }

    fn reader(resource: *Resource) std.io.AnyReader {
        return .{
            .context = resource,
            .readFn = read,
        };
    }

    fn read(context: *const anyopaque, buffer: []u8) anyerror!usize {
        const resource: *Resource = @constCast(@ptrCast(@alignCast(context)));
        switch (resource.*) {
            .file => |*f| return f.read(buffer),
            .http_request => |*r| return r.read(buffer),
            .git => |*g| return g.fetch_stream.read(buffer),
            .dir => unreachable,
        }
    }
};

const FileType = enum {
    tar,
    @"tar.gz",
    @"tar.xz",
    @"tar.zst",
    git_pack,

    fn fromPath(file_path: []const u8) ?FileType {
        if (ascii.endsWithIgnoreCase(file_path, ".tar")) return .tar;
        if (ascii.endsWithIgnoreCase(file_path, ".tgz")) return .@"tar.gz";
        if (ascii.endsWithIgnoreCase(file_path, ".tar.gz")) return .@"tar.gz";
        if (ascii.endsWithIgnoreCase(file_path, ".txz")) return .@"tar.xz";
        if (ascii.endsWithIgnoreCase(file_path, ".tar.xz")) return .@"tar.xz";
        if (ascii.endsWithIgnoreCase(file_path, ".tzst")) return .@"tar.zst";
        if (ascii.endsWithIgnoreCase(file_path, ".tar.zst")) return .@"tar.zst";
        return null;
    }

    /// Parameter is a content-disposition header value.
    fn fromContentDisposition(cd_header: []const u8) ?FileType {
        const attach_end = ascii.indexOfIgnoreCase(cd_header, "attachment;") orelse
            return null;

        var value_start = ascii.indexOfIgnoreCasePos(cd_header, attach_end + 1, "filename") orelse
            return null;
        value_start += "filename".len;
        if (cd_header[value_start] == '*') {
            value_start += 1;
        }
        if (cd_header[value_start] != '=') return null;
        value_start += 1;

        var value_end = std.mem.indexOfPos(u8, cd_header, value_start, ";") orelse cd_header.len;
        if (cd_header[value_end - 1] == '\"') {
            value_end -= 1;
        }
        return fromPath(cd_header[value_start..value_end]);
    }

    test fromContentDisposition {
        try std.testing.expectEqual(@as(?FileType, .@"tar.gz"), fromContentDisposition("attaChment; FILENAME=\"stuff.tar.gz\"; size=42"));
        try std.testing.expectEqual(@as(?FileType, .@"tar.gz"), fromContentDisposition("attachment; filename*=\"stuff.tar.gz\""));
        try std.testing.expectEqual(@as(?FileType, .@"tar.xz"), fromContentDisposition("ATTACHMENT; filename=\"stuff.tar.xz\""));
        try std.testing.expectEqual(@as(?FileType, .@"tar.xz"), fromContentDisposition("attachment; FileName=\"stuff.tar.xz\""));
        try std.testing.expectEqual(@as(?FileType, .@"tar.gz"), fromContentDisposition("attachment; FileName*=UTF-8\'\'xyz%2Fstuff.tar.gz"));

        try std.testing.expect(fromContentDisposition("attachment FileName=\"stuff.tar.gz\"") == null);
        try std.testing.expect(fromContentDisposition("attachment; FileName=\"stuff.tar\"") == null);
        try std.testing.expect(fromContentDisposition("attachment; FileName\"stuff.gz\"") == null);
        try std.testing.expect(fromContentDisposition("attachment; size=42") == null);
        try std.testing.expect(fromContentDisposition("inline; size=42") == null);
        try std.testing.expect(fromContentDisposition("FileName=\"stuff.tar.gz\"; attachment;") == null);
        try std.testing.expect(fromContentDisposition("FileName=\"stuff.tar.gz\";") == null);
    }
};

fn initResource(f: *Fetch, uri: std.Uri) RunError!Resource {
    const gpa = f.arena.child_allocator;
    const arena = f.arena.allocator();
    const eb = &f.error_bundle;

    if (ascii.eqlIgnoreCase(uri.scheme, "file")) return .{
        .file = f.parent_package_root.openFile(uri.path, .{}) catch |err| {
            return f.fail(f.location_tok, try eb.printString("unable to open '{}{s}': {s}", .{
                f.parent_package_root, uri.path, @errorName(err),
            }));
        },
    };

    const http_client = f.job_queue.http_client;

    if (ascii.eqlIgnoreCase(uri.scheme, "http") or
        ascii.eqlIgnoreCase(uri.scheme, "https"))
    {
        var h = std.http.Headers{ .allocator = gpa };
        defer h.deinit();

        var req = http_client.open(.GET, uri, h, .{}) catch |err| {
            return f.fail(f.location_tok, try eb.printString(
                "unable to connect to server: {s}",
                .{@errorName(err)},
            ));
        };
        errdefer req.deinit(); // releases more than memory

        req.send(.{}) catch |err| {
            return f.fail(f.location_tok, try eb.printString(
                "HTTP request failed: {s}",
                .{@errorName(err)},
            ));
        };
        req.wait() catch |err| {
            return f.fail(f.location_tok, try eb.printString(
                "invalid HTTP response: {s}",
                .{@errorName(err)},
            ));
        };

        if (req.response.status != .ok) {
            return f.fail(f.location_tok, try eb.printString(
                "bad HTTP response code: '{d} {s}'",
                .{ @intFromEnum(req.response.status), req.response.status.phrase() orelse "" },
            ));
        }

        return .{ .http_request = req };
    }

    if (ascii.eqlIgnoreCase(uri.scheme, "git+http") or
        ascii.eqlIgnoreCase(uri.scheme, "git+https"))
    {
        var transport_uri = uri;
        transport_uri.scheme = uri.scheme["git+".len..];
        var redirect_uri: []u8 = undefined;
        var session: git.Session = .{ .transport = http_client, .uri = transport_uri };
        session.discoverCapabilities(gpa, &redirect_uri) catch |err| switch (err) {
            error.Redirected => {
                defer gpa.free(redirect_uri);
                return f.fail(f.location_tok, try eb.printString(
                    "repository moved to {s}",
                    .{redirect_uri},
                ));
            },
            else => |e| {
                return f.fail(f.location_tok, try eb.printString(
                    "unable to discover remote git server capabilities: {s}",
                    .{@errorName(e)},
                ));
            },
        };

        const want_oid = want_oid: {
            const want_ref = uri.fragment orelse "HEAD";
            if (git.parseOid(want_ref)) |oid| break :want_oid oid else |_| {}

            const want_ref_head = try std.fmt.allocPrint(arena, "refs/heads/{s}", .{want_ref});
            const want_ref_tag = try std.fmt.allocPrint(arena, "refs/tags/{s}", .{want_ref});

            var ref_iterator = session.listRefs(gpa, .{
                .ref_prefixes = &.{ want_ref, want_ref_head, want_ref_tag },
                .include_peeled = true,
            }) catch |err| {
                return f.fail(f.location_tok, try eb.printString(
                    "unable to list refs: {s}",
                    .{@errorName(err)},
                ));
            };
            defer ref_iterator.deinit();
            while (ref_iterator.next() catch |err| {
                return f.fail(f.location_tok, try eb.printString(
                    "unable to iterate refs: {s}",
                    .{@errorName(err)},
                ));
            }) |ref| {
                if (std.mem.eql(u8, ref.name, want_ref) or
                    std.mem.eql(u8, ref.name, want_ref_head) or
                    std.mem.eql(u8, ref.name, want_ref_tag))
                {
                    break :want_oid ref.peeled orelse ref.oid;
                }
            }
            return f.fail(f.location_tok, try eb.printString("ref not found: {s}", .{want_ref}));
        };
        if (uri.fragment == null) {
            const notes_len = 1;
            try eb.addRootErrorMessage(.{
                .msg = try eb.addString("url field is missing an explicit ref"),
                .src_loc = try f.srcLoc(f.location_tok),
                .notes_len = notes_len,
            });
            const notes_start = try eb.reserveNotes(notes_len);
            eb.extra.items[notes_start] = @intFromEnum(try eb.addErrorMessage(.{
                .msg = try eb.printString("try .url = \"{;+/}#{}\",", .{
                    uri, std.fmt.fmtSliceHexLower(&want_oid),
                }),
            }));
            return error.FetchFailed;
        }

        var want_oid_buf: [git.fmt_oid_length]u8 = undefined;
        _ = std.fmt.bufPrint(&want_oid_buf, "{}", .{
            std.fmt.fmtSliceHexLower(&want_oid),
        }) catch unreachable;
        var fetch_stream = session.fetch(gpa, &.{&want_oid_buf}) catch |err| {
            return f.fail(f.location_tok, try eb.printString(
                "unable to create fetch stream: {s}",
                .{@errorName(err)},
            ));
        };
        errdefer fetch_stream.deinit();

        return .{ .git = .{
            .fetch_stream = fetch_stream,
            .want_oid = want_oid,
        } };
    }

    return f.fail(f.location_tok, try eb.printString(
        "unsupported URL scheme: {s}",
        .{uri.scheme},
    ));
}

fn unpackResource(
    f: *Fetch,
    resource: *Resource,
    uri_path: []const u8,
    tmp_directory: Cache.Directory,
) RunError!void {
    const eb = &f.error_bundle;
    const file_type = switch (resource.*) {
        .file => FileType.fromPath(uri_path) orelse
            return f.fail(f.location_tok, try eb.printString("unknown file type: '{s}'", .{uri_path})),

        .http_request => |req| ft: {
            // Content-Type takes first precedence.
            const content_type = req.response.headers.getFirstValue("Content-Type") orelse
                return f.fail(f.location_tok, try eb.addString("missing 'Content-Type' header"));

            // Extract the MIME type, ignoring charset and boundary directives
            const mime_type_end = std.mem.indexOf(u8, content_type, ";") orelse content_type.len;
            const mime_type = content_type[0..mime_type_end];

            if (ascii.eqlIgnoreCase(mime_type, "application/x-tar"))
                break :ft .tar;

            if (ascii.eqlIgnoreCase(mime_type, "application/gzip") or
                ascii.eqlIgnoreCase(mime_type, "application/x-gzip") or
                ascii.eqlIgnoreCase(mime_type, "application/tar+gzip"))
            {
                break :ft .@"tar.gz";
            }

            if (ascii.eqlIgnoreCase(mime_type, "application/x-xz"))
                break :ft .@"tar.xz";

            if (ascii.eqlIgnoreCase(mime_type, "application/zstd"))
                break :ft .@"tar.zst";

            if (!ascii.eqlIgnoreCase(mime_type, "application/octet-stream") and
                !ascii.eqlIgnoreCase(mime_type, "application/x-compressed"))
            {
                return f.fail(f.location_tok, try eb.printString(
                    "unrecognized 'Content-Type' header: '{s}'",
                    .{content_type},
                ));
            }

            // Next, the filename from 'content-disposition: attachment' takes precedence.
            if (req.response.headers.getFirstValue("Content-Disposition")) |cd_header| {
                break :ft FileType.fromContentDisposition(cd_header) orelse {
                    return f.fail(f.location_tok, try eb.printString(
                        "unsupported Content-Disposition header value: '{s}' for Content-Type=application/octet-stream",
                        .{cd_header},
                    ));
                };
            }

            // Finally, the path from the URI is used.
            break :ft FileType.fromPath(uri_path) orelse {
                return f.fail(f.location_tok, try eb.printString(
                    "unknown file type: '{s}'",
                    .{uri_path},
                ));
            };
        },

        .git => .git_pack,

        .dir => |dir| return f.recursiveDirectoryCopy(dir, tmp_directory.handle) catch |err| {
            return f.fail(f.location_tok, try eb.printString(
                "unable to copy directory '{s}': {s}",
                .{ uri_path, @errorName(err) },
            ));
        },
    };

    switch (file_type) {
        .tar => try unpackTarball(f, tmp_directory.handle, resource.reader()),
        .@"tar.gz" => {
            const reader = resource.reader();
            var br = std.io.bufferedReaderSize(std.crypto.tls.max_ciphertext_record_len, reader);
            var dcp = std.compress.gzip.decompressor(br.reader());
            try unpackTarball(f, tmp_directory.handle, dcp.reader());
        },
        .@"tar.xz" => try unpackTarballCompressed(f, tmp_directory.handle, resource, std.compress.xz),
        .@"tar.zst" => try unpackTarballCompressed(f, tmp_directory.handle, resource, ZstdWrapper),
        .git_pack => unpackGitPack(f, tmp_directory.handle, resource) catch |err| switch (err) {
            error.FetchFailed => return error.FetchFailed,
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| return f.fail(f.location_tok, try eb.printString(
                "unable to unpack git files: {s}",
                .{@errorName(e)},
            )),
        },
    }
}

// due to slight differences in the API of std.compress.(gzip|xz) and std.compress.zstd, zstd is
// wrapped for generic use in unpackTarballCompressed: see github.com/ziglang/zig/issues/14739
const ZstdWrapper = struct {
    fn DecompressType(comptime T: type) type {
        return error{}!std.compress.zstd.DecompressStream(T, .{});
    }

    fn decompress(allocator: Allocator, reader: anytype) DecompressType(@TypeOf(reader)) {
        return std.compress.zstd.decompressStream(allocator, reader);
    }
};

fn unpackTarballCompressed(
    f: *Fetch,
    out_dir: fs.Dir,
    resource: *Resource,
    comptime Compression: type,
) RunError!void {
    const gpa = f.arena.child_allocator;
    const eb = &f.error_bundle;
    const reader = resource.reader();
    var br = std.io.bufferedReaderSize(std.crypto.tls.max_ciphertext_record_len, reader);

    var decompress = Compression.decompress(gpa, br.reader()) catch |err| {
        return f.fail(f.location_tok, try eb.printString(
            "unable to decompress tarball: {s}",
            .{@errorName(err)},
        ));
    };
    defer decompress.deinit();

    return unpackTarball(f, out_dir, decompress.reader());
}

fn unpackTarball(f: *Fetch, out_dir: fs.Dir, reader: anytype) RunError!void {
    const eb = &f.error_bundle;
    const gpa = f.arena.child_allocator;

    var diagnostics: std.tar.Options.Diagnostics = .{ .allocator = gpa };
    defer diagnostics.deinit();

    std.tar.pipeToFileSystem(out_dir, reader, .{
        .diagnostics = &diagnostics,
        .strip_components = 1,
        // TODO: we would like to set this to executable_bit_only, but two
        // things need to happen before that:
        // 1. the tar implementation needs to support it
        // 2. the hashing algorithm here needs to support detecting the is_executable
        //    bit on Windows from the ACLs (see the isExecutable function).
        .mode_mode = .ignore,
        .exclude_empty_directories = true,
    }) catch |err| return f.fail(f.location_tok, try eb.printString(
        "unable to unpack tarball to temporary directory: {s}",
        .{@errorName(err)},
    ));

    if (diagnostics.errors.items.len > 0) {
        const notes_len: u32 = @intCast(diagnostics.errors.items.len);
        try eb.addRootErrorMessage(.{
            .msg = try eb.addString("unable to unpack tarball"),
            .src_loc = try f.srcLoc(f.location_tok),
            .notes_len = notes_len,
        });
        const notes_start = try eb.reserveNotes(notes_len);
        for (diagnostics.errors.items, notes_start..) |item, note_i| {
            switch (item) {
                .unable_to_create_sym_link => |info| {
                    eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                        .msg = try eb.printString("unable to create symlink from '{s}' to '{s}': {s}", .{
                            info.file_name, info.link_name, @errorName(info.code),
                        }),
                    }));
                },
                .unable_to_create_file => |info| {
                    eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                        .msg = try eb.printString("unable to create file '{s}': {s}", .{
                            info.file_name, @errorName(info.code),
                        }),
                    }));
                },
                .unsupported_file_type => |info| {
                    eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                        .msg = try eb.printString("file '{s}' has unsupported type '{c}'", .{
                            info.file_name, @intFromEnum(info.file_type),
                        }),
                    }));
                },
            }
        }
        return error.FetchFailed;
    }
}

fn unpackGitPack(f: *Fetch, out_dir: fs.Dir, resource: *Resource) anyerror!void {
    const eb = &f.error_bundle;
    const gpa = f.arena.child_allocator;
    const want_oid = resource.git.want_oid;
    const reader = resource.git.fetch_stream.reader();
    // The .git directory is used to store the packfile and associated index, but
    // we do not attempt to replicate the exact structure of a real .git
    // directory, since that isn't relevant for fetching a package.
    {
        var pack_dir = try out_dir.makeOpenPath(".git", .{});
        defer pack_dir.close();
        var pack_file = try pack_dir.createFile("pkg.pack", .{ .read = true });
        defer pack_file.close();
        var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
        try fifo.pump(reader, pack_file.writer());
        try pack_file.sync();

        var index_file = try pack_dir.createFile("pkg.idx", .{ .read = true });
        defer index_file.close();
        {
            var index_prog_node = f.prog_node.start("Index pack", 0);
            defer index_prog_node.end();
            index_prog_node.activate();
            var index_buffered_writer = std.io.bufferedWriter(index_file.writer());
            try git.indexPack(gpa, pack_file, index_buffered_writer.writer());
            try index_buffered_writer.flush();
            try index_file.sync();
        }

        {
            var checkout_prog_node = f.prog_node.start("Checkout", 0);
            defer checkout_prog_node.end();
            checkout_prog_node.activate();
            var repository = try git.Repository.init(gpa, pack_file, index_file);
            defer repository.deinit();
            var diagnostics: git.Diagnostics = .{ .allocator = gpa };
            defer diagnostics.deinit();
            try repository.checkout(out_dir, want_oid, &diagnostics);

            if (diagnostics.errors.items.len > 0) {
                const notes_len: u32 = @intCast(diagnostics.errors.items.len);
                try eb.addRootErrorMessage(.{
                    .msg = try eb.addString("unable to unpack packfile"),
                    .src_loc = try f.srcLoc(f.location_tok),
                    .notes_len = notes_len,
                });
                const notes_start = try eb.reserveNotes(notes_len);
                for (diagnostics.errors.items, notes_start..) |item, note_i| {
                    switch (item) {
                        .unable_to_create_sym_link => |info| {
                            eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                                .msg = try eb.printString("unable to create symlink from '{s}' to '{s}': {s}", .{
                                    info.file_name, info.link_name, @errorName(info.code),
                                }),
                            }));
                        },
                    }
                }
                return error.InvalidGitPack;
            }
        }
    }

    try out_dir.deleteTree(".git");
}

fn recursiveDirectoryCopy(f: *Fetch, dir: fs.Dir, tmp_dir: fs.Dir) anyerror!void {
    const gpa = f.arena.child_allocator;
    // Recursive directory copy.
    var it = try dir.walk(gpa);
    defer it.deinit();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {}, // omit empty directories
            .file => {
                dir.copyFile(
                    entry.path,
                    tmp_dir,
                    entry.path,
                    .{},
                ) catch |err| switch (err) {
                    error.FileNotFound => {
                        if (fs.path.dirname(entry.path)) |dirname| try tmp_dir.makePath(dirname);
                        try dir.copyFile(entry.path, tmp_dir, entry.path, .{});
                    },
                    else => |e| return e,
                };
            },
            .sym_link => {
                var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
                const link_name = try dir.readLink(entry.path, &buf);
                // TODO: if this would create a symlink to outside
                // the destination directory, fail with an error instead.
                tmp_dir.symLink(link_name, entry.path, .{}) catch |err| switch (err) {
                    error.FileNotFound => {
                        if (fs.path.dirname(entry.path)) |dirname| try tmp_dir.makePath(dirname);
                        try tmp_dir.symLink(link_name, entry.path, .{});
                    },
                    else => |e| return e,
                };
            },
            else => return error.IllegalFileTypeInPackage,
        }
    }
}

pub fn renameTmpIntoCache(
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
                cache_dir.deleteTree(tmp_dir_sub_path) catch {
                    // Garbage files leftover in zig-cache/tmp/ is, as they say
                    // on Star Trek, "operating within normal parameters".
                };
            },
            else => |e| return e,
        };
        break;
    }
}

/// Assumes that files not included in the package have already been filtered
/// prior to calling this function. This ensures that files not protected by
/// the hash are not present on the file system. Empty directories are *not
/// hashed* and must not be present on the file system when calling this
/// function.
fn computeHash(
    f: *Fetch,
    tmp_directory: Cache.Directory,
    filter: Filter,
) RunError!Manifest.Digest {
    // All the path name strings need to be in memory for sorting.
    const arena = f.arena.allocator();
    const gpa = f.arena.child_allocator;
    const eb = &f.error_bundle;
    const thread_pool = f.job_queue.thread_pool;

    // Collect all files, recursively, then sort.
    var all_files = std.ArrayList(*HashedFile).init(gpa);
    defer all_files.deinit();

    var deleted_files = std.ArrayList(*DeletedFile).init(gpa);
    defer deleted_files.deinit();

    // Track directories which had any files deleted from them so that empty directories
    // can be deleted.
    var sus_dirs: std.StringArrayHashMapUnmanaged(void) = .{};
    defer sus_dirs.deinit(gpa);

    var walker = try tmp_directory.handle.walk(gpa);
    defer walker.deinit();

    {
        // The final hash will be a hash of each file hashed independently. This
        // allows hashing in parallel.
        var wait_group: WaitGroup = .{};
        // `computeHash` is called from a worker thread so there must not be
        // any waiting without working or a deadlock could occur.
        defer thread_pool.waitAndWork(&wait_group);

        while (walker.next() catch |err| {
            try eb.addRootErrorMessage(.{ .msg = try eb.printString(
                "unable to walk temporary directory '{}': {s}",
                .{ tmp_directory, @errorName(err) },
            ) });
            return error.FetchFailed;
        }) |entry| {
            if (entry.kind == .directory) continue;

            if (!filter.includePath(entry.path)) {
                // Delete instead of including in hash calculation.
                const fs_path = try arena.dupe(u8, entry.path);

                // Also track the parent directory in case it becomes empty.
                if (fs.path.dirname(fs_path)) |parent|
                    try sus_dirs.put(gpa, parent, {});

                const deleted_file = try arena.create(DeletedFile);
                deleted_file.* = .{
                    .fs_path = fs_path,
                    .failure = undefined, // to be populated by the worker
                };
                wait_group.start();
                try thread_pool.spawn(workerDeleteFile, .{
                    tmp_directory.handle, deleted_file, &wait_group,
                });
                try deleted_files.append(deleted_file);
                continue;
            }

            const kind: HashedFile.Kind = switch (entry.kind) {
                .directory => unreachable,
                .file => .file,
                .sym_link => .link,
                else => return f.fail(f.location_tok, try eb.printString(
                    "package contains '{s}' which has illegal file type '{s}'",
                    .{ entry.path, @tagName(entry.kind) },
                )),
            };

            if (std.mem.eql(u8, entry.path, Package.build_zig_basename))
                f.has_build_zig = true;

            const fs_path = try arena.dupe(u8, entry.path);
            const hashed_file = try arena.create(HashedFile);
            hashed_file.* = .{
                .fs_path = fs_path,
                .normalized_path = try normalizePathAlloc(arena, fs_path),
                .kind = kind,
                .hash = undefined, // to be populated by the worker
                .failure = undefined, // to be populated by the worker
            };
            wait_group.start();
            try thread_pool.spawn(workerHashFile, .{
                tmp_directory.handle, hashed_file, &wait_group,
            });
            try all_files.append(hashed_file);
        }
    }

    {
        // Sort by length, descending, so that child directories get removed first.
        sus_dirs.sortUnstable(@as(struct {
            keys: []const []const u8,
            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                return ctx.keys[b_index].len < ctx.keys[a_index].len;
            }
        }, .{ .keys = sus_dirs.keys() }));

        // During this loop, more entries will be added, so we must loop by index.
        var i: usize = 0;
        while (i < sus_dirs.count()) : (i += 1) {
            const sus_dir = sus_dirs.keys()[i];
            tmp_directory.handle.deleteDir(sus_dir) catch |err| switch (err) {
                error.DirNotEmpty => continue,
                error.FileNotFound => continue,
                else => |e| {
                    try eb.addRootErrorMessage(.{ .msg = try eb.printString(
                        "unable to delete empty directory '{s}': {s}",
                        .{ sus_dir, @errorName(e) },
                    ) });
                    return error.FetchFailed;
                },
            };
            if (fs.path.dirname(sus_dir)) |parent| {
                try sus_dirs.put(gpa, parent, {});
            }
        }
    }

    std.mem.sortUnstable(*HashedFile, all_files.items, {}, HashedFile.lessThan);

    var hasher = Manifest.Hash.init(.{});
    var any_failures = false;
    for (all_files.items) |hashed_file| {
        hashed_file.failure catch |err| {
            any_failures = true;
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("unable to hash '{s}': {s}", .{
                    hashed_file.fs_path, @errorName(err),
                }),
            });
        };
        hasher.update(&hashed_file.hash);
    }
    for (deleted_files.items) |deleted_file| {
        deleted_file.failure catch |err| {
            any_failures = true;
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("failed to delete excluded path '{s}' from package: {s}", .{
                    deleted_file.fs_path, @errorName(err),
                }),
            });
        };
    }

    if (any_failures) return error.FetchFailed;

    if (f.job_queue.debug_hash) {
        assert(!f.job_queue.recursive);
        // Print something to stdout that can be text diffed to figure out why
        // the package hash is different.
        dumpHashInfo(all_files.items) catch |err| {
            std.debug.print("unable to write to stdout: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        };
    }

    return hasher.finalResult();
}

fn dumpHashInfo(all_files: []const *const HashedFile) !void {
    const stdout = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout.writer());
    const w = bw.writer();

    for (all_files) |hashed_file| {
        try w.print("{s}: {s}: {s}\n", .{
            @tagName(hashed_file.kind),
            std.fmt.fmtSliceHexLower(&hashed_file.hash),
            hashed_file.normalized_path,
        });
    }

    try bw.flush();
}

fn workerHashFile(dir: fs.Dir, hashed_file: *HashedFile, wg: *WaitGroup) void {
    defer wg.finish();
    hashed_file.failure = hashFileFallible(dir, hashed_file);
}

fn workerDeleteFile(dir: fs.Dir, deleted_file: *DeletedFile, wg: *WaitGroup) void {
    defer wg.finish();
    deleted_file.failure = deleteFileFallible(dir, deleted_file);
}

fn hashFileFallible(dir: fs.Dir, hashed_file: *HashedFile) HashedFile.Error!void {
    var buf: [8000]u8 = undefined;
    var hasher = Manifest.Hash.init(.{});
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
        .link => {
            const link_name = try dir.readLink(hashed_file.fs_path, &buf);
            if (fs.path.sep != canonical_sep) {
                // Package hashes are intended to be consistent across
                // platforms which means we must normalize path separators
                // inside symlinks.
                normalizePath(link_name);
            }
            hasher.update(link_name);
        },
    }
    hasher.final(&hashed_file.hash);
}

fn deleteFileFallible(dir: fs.Dir, deleted_file: *DeletedFile) DeletedFile.Error!void {
    try dir.deleteFile(deleted_file.fs_path);
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

const DeletedFile = struct {
    fs_path: []const u8,
    failure: Error!void,

    const Error =
        fs.Dir.DeleteFileError ||
        fs.Dir.DeleteDirError;
};

const HashedFile = struct {
    fs_path: []const u8,
    normalized_path: []const u8,
    hash: Manifest.Digest,
    failure: Error!void,
    kind: Kind,

    const Error =
        fs.File.OpenError ||
        fs.File.ReadError ||
        fs.File.StatError ||
        fs.Dir.ReadLinkError;

    const Kind = enum { file, link };

    fn lessThan(context: void, lhs: *const HashedFile, rhs: *const HashedFile) bool {
        _ = context;
        return std.mem.lessThan(u8, lhs.normalized_path, rhs.normalized_path);
    }
};

/// Make a file system path identical independently of operating system path inconsistencies.
/// This converts backslashes into forward slashes.
fn normalizePathAlloc(arena: Allocator, fs_path: []const u8) ![]const u8 {
    if (fs.path.sep == canonical_sep) return fs_path;
    const normalized = try arena.dupe(u8, fs_path);
    normalizePath(normalized);
    return normalized;
}

const canonical_sep = fs.path.sep_posix;

fn normalizePath(bytes: []u8) void {
    assert(fs.path.sep != canonical_sep);
    std.mem.replaceScalar(u8, bytes, fs.path.sep, canonical_sep);
}

const Filter = struct {
    include_paths: std.StringArrayHashMapUnmanaged(void) = .{},

    /// sub_path is relative to the package root.
    pub fn includePath(self: Filter, sub_path: []const u8) bool {
        if (self.include_paths.count() == 0) return true;
        if (self.include_paths.contains("")) return true;
        if (self.include_paths.contains(".")) return true;
        if (self.include_paths.contains(sub_path)) return true;

        // Check if any included paths are parent directories of sub_path.
        var dirname = sub_path;
        while (std.fs.path.dirname(dirname)) |next_dirname| {
            if (self.include_paths.contains(next_dirname)) return true;
            dirname = next_dirname;
        }

        return false;
    }

    test includePath {
        const gpa = std.testing.allocator;
        var filter: Filter = .{};
        defer filter.include_paths.deinit(gpa);

        try filter.include_paths.put(gpa, "src", {});
        try std.testing.expect(filter.includePath("src/core/unix/SDL_poll.c"));
        try std.testing.expect(!filter.includePath(".gitignore"));
    }
};

pub fn depDigest(
    pkg_root: Package.Path,
    cache_root: Cache.Directory,
    dep: Manifest.Dependency,
) ?Manifest.MultiHashHexDigest {
    if (dep.hash) |h| return h[0..Manifest.multihash_hex_digest_len].*;

    switch (dep.location) {
        .url => return null,
        .path => |rel_path| {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const new_root = pkg_root.resolvePosix(fba.allocator(), rel_path) catch
                return null;
            return relativePathDigest(new_root, cache_root);
        },
    }
}

// These are random bytes.
const package_hash_prefix_cached = [8]u8{ 0x53, 0x7e, 0xfa, 0x94, 0x65, 0xe9, 0xf8, 0x73 };
const package_hash_prefix_project = [8]u8{ 0xe1, 0x25, 0xee, 0xfa, 0xa6, 0x17, 0x38, 0xcc };

const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const assert = std.debug.assert;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const Fetch = @This();
const main = @import("../main.zig");
const git = @import("Fetch/git.zig");
const Package = @import("../Package.zig");
const Manifest = Package.Manifest;
const ErrorBundle = std.zig.ErrorBundle;

test {
    _ = Filter;
    _ = FileType;
}
