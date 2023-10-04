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

/// Try to avoid this as much as possible since arena will have less contention.
gpa: Allocator,
arena: std.heap.ArenaAllocator,
location: Location,
location_tok: std.zig.Ast.TokenIndex,
hash_tok: std.zig.Ast.TokenIndex,
global_cache: Cache.Directory,
parent_package_root: Path,
parent_manifest_ast: ?*const std.zig.Ast,
prog_node: *std.Progress.Node,
http_client: *std.http.Client,
thread_pool: *ThreadPool,
job_queue: *JobQueue,
wait_group: *WaitGroup,

// Above this are fields provided as inputs to `run`.
// Below this are fields populated by `run`.

/// This will either be relative to `global_cache`, or to the build root of
/// the root package.
package_root: Path,
error_bundle: std.zig.ErrorBundle.Wip,
manifest: ?Manifest,
manifest_ast: ?*std.zig.Ast,
actual_hash: Digest,
/// Fetch logic notices whether a package has a build.zig file and sets this flag.
has_build_zig: bool,
/// Indicates whether the task aborted due to an out-of-memory condition.
oom_flag: bool,

pub const JobQueue = struct {
    mutex: std.Thread.Mutex = .{},
};

pub const Digest = [Manifest.Hash.digest_length]u8;
pub const MultiHashHexDigest = [hex_multihash_len]u8;

pub const Path = struct {
    root_dir: Cache.Directory,
    /// The path, relative to the root dir, that this `Path` represents.
    /// Empty string means the root_dir is the path.
    sub_path: []const u8 = "",
};

pub const Location = union(enum) {
    remote: Remote,
    relative_path: []const u8,

    pub const Remote = struct {
        url: []const u8,
        /// If this is null it means the user omitted the hash field from a dependency.
        /// It will be an error but the logic should still fetch and print the discovered hash.
        hash: ?[hex_multihash_len]u8,
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
    const arena = f.arena_allocator.allocator();

    // Check the global zig package cache to see if the hash already exists. If
    // so, load, parse, and validate the build.zig.zon file therein, and skip
    // ahead to queuing up jobs for dependencies. Likewise if the location is a
    // relative path, treat this the same as a cache hit. Otherwise, proceed.

    const remote = switch (f.location) {
        .relative_path => |sub_path| {
            if (fs.path.isAbsolute(sub_path)) return f.fail(
                f.location_tok,
                try eb.addString("expected path relative to build root; found absolute path"),
            );
            if (f.hash_tok != 0) return f.fail(
                f.hash_tok,
                try eb.addString("path-based dependencies are not hashed"),
            );
            f.package_root = try f.parent_package_root.join(arena, sub_path);
            try loadManifest(f, f.package_root);
            // Package hashes are used as unique identifiers for packages, so
            // we still need one for relative paths.
            const hash = h: {
                var hasher = Manifest.Hash.init(.{});
                // This hash is a tuple of:
                // * whether it relative to the global cache directory or to the root package
                // * the relative file path from there to the build root of the package
                hasher.update(if (f.package_root.root_dir.handle == f.global_cache.handle)
                    &package_hash_prefix_cached
                else
                    &package_hash_prefix_project);
                hasher.update(f.package_root.sub_path);
                break :h hasher.finalResult();
            };
            return queueJobsForDeps(f, hash);
        },
        .remote => |remote| remote,
    };
    const s = fs.path.sep_str;
    if (remote.hash) |expected_hash| {
        const pkg_sub_path = "p" ++ s ++ expected_hash;
        if (f.global_cache.handle.access(pkg_sub_path, .{})) |_| {
            f.package_root = .{
                .root_dir = f.global_cache,
                .sub_path = pkg_sub_path,
            };
            try loadManifest(f, f.package_root);
            return queueJobsForDeps(f, expected_hash);
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| {
                try eb.addRootErrorMessage(.{
                    .msg = try eb.printString("unable to open global package cache directory '{s}': {s}", .{
                        try f.global_cache.join(arena, .{pkg_sub_path}), @errorName(e),
                    }),
                    .src_loc = .none,
                    .notes_len = 0,
                });
                return error.FetchFailed;
            },
        }
    }

    // Fetch and unpack the remote into a temporary directory.

    const uri = std.Uri.parse(remote.url) catch |err| return f.fail(
        f.location_tok,
        "invalid URI: {s}",
        .{@errorName(err)},
    );
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ s ++ Manifest.hex64(rand_int);

    var tmp_directory: Cache.Directory = .{
        .path = try f.global_cache.join(arena, &.{tmp_dir_sub_path}),
        .handle = (try f.global_cache.handle.makeOpenPathIterable(tmp_dir_sub_path, .{})).dir,
    };
    defer tmp_directory.handle.close();

    var resource = try f.initResource(uri);
    defer resource.deinit(); // releases more than memory

    try f.unpackResource(&resource, uri.path, tmp_directory);

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

    if (builtin.os.tag == .linux and f.work_around_btrfs_bug) {
        // https://github.com/ziglang/zig/issues/17095
        tmp_directory.handle.close();
        const iterable_dir = f.global_cache.handle.makeOpenPathIterable(tmp_dir_sub_path, .{}) catch
            @panic("btrfs workaround failed");
        tmp_directory.handle = iterable_dir.dir;
    }

    f.actual_hash = try computeHash(f, .{ .dir = tmp_directory.handle }, filter);

    // Rename the temporary directory into the global zig package cache
    // directory. If the hash already exists, delete the temporary directory
    // and leave the zig package cache directory untouched as it may be in use
    // by the system. This is done even if the hash is invalid, in case the
    // package with the different hash is used in the future.

    const dest_pkg_sub_path = "p" ++ s ++ Manifest.hexDigest(f.actual_hash);
    try renameTmpIntoCache(f.global_cache.handle, tmp_dir_sub_path, dest_pkg_sub_path);

    // Validate the computed hash against the expected hash. If invalid, this
    // job is done.

    const actual_hex = Manifest.hexDigest(f.actual_hash);
    if (remote.hash) |declared_hash| {
        if (!std.mem.eql(u8, declared_hash, &actual_hex)) {
            return f.fail(f.hash_tok, "hash mismatch: manifest declares {s} but the fetched package has {s}", .{
                declared_hash, actual_hex,
            });
        }
    } else {
        const notes_len = 1;
        try f.addErrorWithNotes(notes_len, f.location_tok, "dependency is missing hash field");
        const notes_start = try eb.reserveNotes(notes_len);
        eb.extra.items[notes_start] = @intFromEnum(try eb.addErrorMessage(.{
            .msg = try eb.printString("expected .hash = \"{s}\",", .{&actual_hex}),
        }));
        return error.PackageFetchFailed;
    }

    // Spawn a new fetch job for each dependency in the manifest file. Use
    // a mutex and a hash map so that redundant jobs do not get queued up.
    return queueJobsForDeps(f, .{ .hash = f.actual_hash });
}

/// This function populates `f.manifest` or leaves it `null`.
fn loadManifest(f: *Fetch, pkg_root: Path) RunError!void {
    const eb = &f.error_bundle;
    const arena = f.arena_allocator.allocator();
    const manifest_bytes = pkg_root.readFileAllocOptions(
        arena,
        Manifest.basename,
        Manifest.max_bytes,
        null,
        1,
        0,
    ) catch |err| switch (err) {
        error.FileNotFound => return,
        else => |e| {
            const file_path = try pkg_root.join(arena, .{Manifest.basename});
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("unable to load package manifest '{s}': {s}", .{
                    file_path, @errorName(e),
                }),
                .src_loc = .none,
                .notes_len = 0,
            });
        },
    };

    var ast = try std.zig.Ast.parse(arena, manifest_bytes, .zon);
    f.manifest_ast = ast;

    if (ast.errors.len > 0) {
        const file_path = try pkg_root.join(arena, .{Manifest.basename});
        try main.putAstErrorsIntoBundle(arena, ast, file_path, eb);
        return error.PackageFetchFailed;
    }

    f.manifest = try Manifest.parse(arena, ast);

    if (f.manifest.errors.len > 0) {
        const file_path = try pkg_root.join(arena, .{Manifest.basename});
        const token_starts = ast.tokens.items(.start);

        for (f.manifest.errors) |msg| {
            const start_loc = ast.tokenLocation(0, msg.tok);

            try eb.addRootErrorMessage(.{
                .msg = try eb.addString(msg.msg),
                .src_loc = try eb.addSourceLocation(.{
                    .src_path = try eb.addString(file_path),
                    .span_start = token_starts[msg.tok],
                    .span_end = @intCast(token_starts[msg.tok] + ast.tokenSlice(msg.tok).len),
                    .span_main = token_starts[msg.tok] + msg.off,
                    .line = @intCast(start_loc.line),
                    .column = @intCast(start_loc.column),
                    .source_line = try eb.addString(ast.source[start_loc.line_start..start_loc.line_end]),
                }),
                .notes_len = 0,
            });
        }
        return error.PackageFetchFailed;
    }
}

fn queueJobsForDeps(f: *Fetch, hash: Digest) RunError!void {
    // If the package does not have a build.zig.zon file then there are no dependencies.
    const manifest = f.manifest orelse return;

    const new_fetches = nf: {
        // Grab the new tasks into a temporary buffer so we can unlock that mutex
        // as fast as possible.
        // This overallocates any fetches that get skipped by the `continue` in the
        // loop below.
        const new_fetches = try f.arena.alloc(Fetch, manifest.dependencies.count());
        var new_fetch_index: usize = 0;

        f.job_queue.lock();
        defer f.job_queue.unlock();

        // It is impossible for there to be a collision here. Consider all three cases:
        // * Correct hash is provided by manifest.
        //   - Redundant jobs are skipped in the loop below.
        // * Incorrect has is provided by manifest.
        //   - Hash mismatch error emitted; `queueJobsForDeps` is not called.
        // * Hash is not provided by manifest.
        //   - Hash missing error emitted; `queueJobsForDeps` is not called.
        try f.job_queue.finish(hash, f, new_fetches.len);

        for (manifest.dependencies.values()) |dep| {
            const location: Location = switch (dep.location) {
                .url => |url| .{ .remote = .{
                    .url = url,
                    .hash = if (dep.hash) |h| h[0..hex_multihash_len].* else null,
                } },
                .path => |path| .{ .relative_path = path },
            };
            const new_fetch = &new_fetches[new_fetch_index];
            const already_done = f.job_queue.add(location, new_fetch);
            if (already_done) continue;
            new_fetch_index += 1;

            new_fetch.* = .{
                .gpa = f.gpa,
                .arena = std.heap.ArenaAllocator.init(f.gpa),
                .location = location,
                .location_tok = dep.location_tok,
                .hash_tok = dep.hash_tok,
                .global_cache = f.global_cache,
                .parent_package_root = f.package_root,
                .parent_manifest_ast = f.manifest_ast.?,
                .prog_node = f.prog_node,
                .http_client = f.http_client,
                .thread_pool = f.thread_pool,
                .job_queue = f.job_queue,
                .wait_group = f.wait_group,

                .package_root = undefined,
                .error_bundle = .{},
                .manifest = null,
                .manifest_ast = null,
                .actual_hash = undefined,
                .has_build_zig = false,
            };
        }

        break :nf new_fetches[0..new_fetch_index];
    };

    // Now it's time to give tasks to the thread pool.
    for (new_fetches) |new_fetch| {
        f.wait_group.start();
        f.thread_pool.spawn(workerRun, .{f}) catch |err| switch (err) {
            error.OutOfMemory => {
                new_fetch.oom_flag = true;
                f.wait_group.finish();
                continue;
            },
        };
    }
}

fn workerRun(f: *Fetch) void {
    defer f.wait_group.finish();
    run(f) catch |err| switch (err) {
        error.OutOfMemory => f.oom_flag = true,
        error.FetchFailed => {}, // See `error_bundle`.
    };
}

fn fail(f: *Fetch, msg_tok: std.zig.Ast.TokenIndex, msg_str: u32) RunError!void {
    const ast = f.parent_manifest_ast;
    const token_starts = ast.tokens.items(.start);
    const start_loc = ast.tokenLocation(0, msg_tok);
    const eb = &f.error_bundle;
    const file_path = try f.parent_package_root.join(f.arena, Manifest.basename);
    const msg_off = 0;

    try eb.addRootErrorMessage(.{
        .msg = msg_str,
        .src_loc = try eb.addSourceLocation(.{
            .src_path = try eb.addString(file_path),
            .span_start = token_starts[msg_tok],
            .span_end = @intCast(token_starts[msg_tok] + ast.tokenSlice(msg_tok).len),
            .span_main = token_starts[msg_tok] + msg_off,
            .line = @intCast(start_loc.line),
            .column = @intCast(start_loc.column),
            .source_line = try eb.addString(ast.source[start_loc.line_start..start_loc.line_end]),
        }),
        .notes_len = 0,
    });

    return error.FetchFailed;
}

const Resource = union(enum) {
    file: fs.File,
    http_request: std.http.Client.Request,
    git_fetch_stream: git.Session.FetchStream,
    dir: fs.IterableDir,
};

const FileType = enum {
    tar,
    @"tar.gz",
    @"tar.xz",
    git_pack,

    fn fromPath(file_path: []const u8) ?FileType {
        if (ascii.endsWithIgnoreCase(file_path, ".tar")) return .tar;
        if (ascii.endsWithIgnoreCase(file_path, ".tar.gz")) return .@"tar.gz";
        if (ascii.endsWithIgnoreCase(file_path, ".tar.xz")) return .@"tar.xz";
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
    const gpa = f.gpa;
    const arena = f.arena_allocator.allocator();
    const eb = &f.error_bundle;

    if (ascii.eqlIgnoreCase(uri.scheme, "file")) return .{
        .file = try f.parent_package_root.openFile(uri.path, .{}),
    };

    if (ascii.eqlIgnoreCase(uri.scheme, "http") or
        ascii.eqlIgnoreCase(uri.scheme, "https"))
    {
        var h = std.http.Headers{ .allocator = gpa };
        defer h.deinit();

        var req = try f.http_client.request(.GET, uri, h, .{});
        errdefer req.deinit(); // releases more than memory

        try req.start(.{});
        try req.wait();

        if (req.response.status != .ok) {
            return f.fail(f.location_tok, "expected response status '200 OK' got '{s} {s}'", .{
                @intFromEnum(req.response.status), req.response.status.phrase() orelse "",
            });
        }

        return .{ .http_request = req };
    }

    if (ascii.eqlIgnoreCase(uri.scheme, "git+http") or
        ascii.eqlIgnoreCase(uri.scheme, "git+https"))
    {
        var transport_uri = uri;
        transport_uri.scheme = uri.scheme["git+".len..];
        var redirect_uri: []u8 = undefined;
        var session: git.Session = .{ .transport = f.http_client, .uri = transport_uri };
        session.discoverCapabilities(gpa, &redirect_uri) catch |e| switch (e) {
            error.Redirected => {
                defer gpa.free(redirect_uri);
                return f.fail(f.location_tok, "repository moved to {s}", .{redirect_uri});
            },
            else => |other| return other,
        };

        const want_oid = want_oid: {
            const want_ref = uri.fragment orelse "HEAD";
            if (git.parseOid(want_ref)) |oid| break :want_oid oid else |_| {}

            const want_ref_head = try std.fmt.allocPrint(arena, "refs/heads/{s}", .{want_ref});
            const want_ref_tag = try std.fmt.allocPrint(arena, "refs/tags/{s}", .{want_ref});

            var ref_iterator = try session.listRefs(gpa, .{
                .ref_prefixes = &.{ want_ref, want_ref_head, want_ref_tag },
                .include_peeled = true,
            });
            defer ref_iterator.deinit();
            while (try ref_iterator.next()) |ref| {
                if (std.mem.eql(u8, ref.name, want_ref) or
                    std.mem.eql(u8, ref.name, want_ref_head) or
                    std.mem.eql(u8, ref.name, want_ref_tag))
                {
                    break :want_oid ref.peeled orelse ref.oid;
                }
            }
            return f.fail(f.location_tok, "ref not found: {s}", .{want_ref});
        };
        if (uri.fragment == null) {
            const notes_len = 1;
            try f.addErrorWithNotes(notes_len, f.location_tok, "url field is missing an explicit ref");
            const notes_start = try eb.reserveNotes(notes_len);
            eb.extra.items[notes_start] = @intFromEnum(try eb.addErrorMessage(.{
                .msg = try eb.printString("try .url = \"{+/}#{}\",", .{
                    uri, std.fmt.fmtSliceHexLower(&want_oid),
                }),
            }));
            return error.PackageFetchFailed;
        }

        var want_oid_buf: [git.fmt_oid_length]u8 = undefined;
        _ = std.fmt.bufPrint(&want_oid_buf, "{}", .{
            std.fmt.fmtSliceHexLower(&want_oid),
        }) catch unreachable;
        var fetch_stream = try session.fetch(gpa, &.{&want_oid_buf});
        errdefer fetch_stream.deinit();

        return .{ .git_fetch_stream = fetch_stream };
    }

    return f.fail(f.location_tok, "unsupported URL scheme: {s}", .{uri.scheme});
}

fn unpackResource(
    f: *Fetch,
    resource: *Resource,
    uri_path: []const u8,
    tmp_directory: Cache.Directory,
) RunError!void {
    const file_type = switch (resource.*) {
        .file => FileType.fromPath(uri_path) orelse
            return f.fail(f.location_tok, "unknown file type: '{s}'", .{uri_path}),

        .http_request => |req| ft: {
            // Content-Type takes first precedence.
            const content_type = req.response.headers.getFirstValue("Content-Type") orelse
                return f.fail(f.location_tok, "missing 'Content-Type' header", .{});

            if (ascii.eqlIgnoreCase(content_type, "application/x-tar"))
                return .tar;

            if (ascii.eqlIgnoreCase(content_type, "application/gzip") or
                ascii.eqlIgnoreCase(content_type, "application/x-gzip") or
                ascii.eqlIgnoreCase(content_type, "application/tar+gzip"))
            {
                return .@"tar.gz";
            }

            if (ascii.eqlIgnoreCase(content_type, "application/x-xz"))
                return .@"tar.xz";

            if (!ascii.eqlIgnoreCase(content_type, "application/octet-stream")) {
                return f.fail(f.location_tok, "unrecognized 'Content-Type' header: '{s}'", .{
                    content_type,
                });
            }

            // Next, the filename from 'content-disposition: attachment' takes precedence.
            if (req.response.headers.getFirstValue("Content-Disposition")) |cd_header| {
                break :ft FileType.fromContentDisposition(cd_header) orelse
                    return f.fail(
                    f.location_tok,
                    "unsupported Content-Disposition header value: '{s}' for Content-Type=application/octet-stream",
                    .{cd_header},
                );
            }

            // Finally, the path from the URI is used.
            break :ft FileType.fromPath(uri_path) orelse
                return f.fail(f.location_tok, "unknown file type: '{s}'", .{uri_path});
        },
        .git_fetch_stream => return .git_pack,
        .dir => |dir| {
            try f.recursiveDirectoryCopy(dir, tmp_directory.handle);
            return;
        },
    };

    switch (file_type) {
        .tar => try unpackTarball(f, tmp_directory.handle, resource.reader()),
        .@"tar.gz" => try unpackTarballCompressed(f, tmp_directory.handle, resource, std.compress.gzip),
        .@"tar.xz" => try unpackTarballCompressed(f, tmp_directory.handle, resource, std.compress.xz),
        .git_pack => try unpackGitPack(f, tmp_directory.handle, resource),
    }
}

fn unpackTarballCompressed(
    f: *Fetch,
    out_dir: fs.Dir,
    resource: *Resource,
    comptime Compression: type,
) RunError!void {
    const gpa = f.gpa;
    const reader = resource.reader();
    var br = std.io.bufferedReaderSize(std.crypto.tls.max_ciphertext_record_len, reader);

    var decompress = try Compression.decompress(gpa, br.reader());
    defer decompress.deinit();

    return unpackTarball(f, out_dir, decompress.reader());
}

fn unpackTarball(f: *Fetch, out_dir: fs.Dir, reader: anytype) RunError!void {
    const eb = &f.error_bundle;

    var diagnostics: std.tar.Options.Diagnostics = .{ .allocator = f.gpa };
    defer diagnostics.deinit();

    try std.tar.pipeToFileSystem(out_dir, reader, .{
        .diagnostics = &diagnostics,
        .strip_components = 1,
        // TODO: we would like to set this to executable_bit_only, but two
        // things need to happen before that:
        // 1. the tar implementation needs to support it
        // 2. the hashing algorithm here needs to support detecting the is_executable
        //    bit on Windows from the ACLs (see the isExecutable function).
        .mode_mode = .ignore,
        .filter = .{ .exclude_empty_directories = true },
    });

    if (diagnostics.errors.items.len > 0) {
        const notes_len: u32 = @intCast(diagnostics.errors.items.len);
        try f.addErrorWithNotes(notes_len, f.location_tok, "unable to unpack tarball");
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
                .unsupported_file_type => |info| {
                    eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                        .msg = try eb.printString("file '{s}' has unsupported type '{c}'", .{
                            info.file_name, @intFromEnum(info.file_type),
                        }),
                    }));
                },
            }
        }
        return error.InvalidTarball;
    }
}

fn unpackGitPack(
    f: *Fetch,
    out_dir: fs.Dir,
    resource: *Resource,
    want_oid: git.Oid,
) !void {
    const eb = &f.error_bundle;
    const gpa = f.gpa;
    const reader = resource.reader();
    // The .git directory is used to store the packfile and associated index, but
    // we do not attempt to replicate the exact structure of a real .git
    // directory, since that isn't relevant for fetching a package.
    {
        var pack_dir = try out_dir.makeOpenPath(".git", .{});
        defer pack_dir.close();
        var pack_file = try pack_dir.createFile("pkg.pack", .{ .read = true });
        defer pack_file.close();
        var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
        try fifo.pump(reader.reader(), pack_file.writer());
        try pack_file.sync();

        var index_file = try pack_dir.createFile("pkg.idx", .{ .read = true });
        defer index_file.close();
        {
            var index_prog_node = reader.prog_node.start("Index pack", 0);
            defer index_prog_node.end();
            index_prog_node.activate();
            var index_buffered_writer = std.io.bufferedWriter(index_file.writer());
            try git.indexPack(gpa, pack_file, index_buffered_writer.writer());
            try index_buffered_writer.flush();
            try index_file.sync();
        }

        {
            var checkout_prog_node = reader.prog_node.start("Checkout", 0);
            defer checkout_prog_node.end();
            checkout_prog_node.activate();
            var repository = try git.Repository.init(gpa, pack_file, index_file);
            defer repository.deinit();
            var diagnostics: git.Diagnostics = .{ .allocator = gpa };
            defer diagnostics.deinit();
            try repository.checkout(out_dir, want_oid, &diagnostics);

            if (diagnostics.errors.items.len > 0) {
                const notes_len: u32 = @intCast(diagnostics.errors.items.len);
                try f.addErrorWithNotes(notes_len, f.location_tok, "unable to unpack packfile");
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

fn recursiveDirectoryCopy(f: *Fetch, dir: fs.IterableDir, tmp_dir: fs.Dir) RunError!void {
    // Recursive directory copy.
    var it = try dir.walk(f.gpa);
    defer it.deinit();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {}, // omit empty directories
            .file => {
                dir.dir.copyFile(
                    entry.path,
                    tmp_dir,
                    entry.path,
                    .{},
                ) catch |err| switch (err) {
                    error.FileNotFound => {
                        if (fs.path.dirname(entry.path)) |dirname| try tmp_dir.makePath(dirname);
                        try dir.dir.copyFile(entry.path, tmp_dir, entry.path, .{});
                    },
                    else => |e| return e,
                };
            },
            .sym_link => {
                var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
                const link_name = try dir.dir.readLink(entry.path, &buf);
                // TODO: if this would create a symlink to outside
                // the destination directory, fail with an error instead.
                try tmp_dir.symLink(link_name, entry.path, .{});
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
fn computeHash(f: *Fetch, pkg_dir: fs.IterableDir, filter: Filter) RunError!Digest {
    // All the path name strings need to be in memory for sorting.
    const arena = f.arena_allocator.allocator();
    const gpa = f.gpa;

    // Collect all files, recursively, then sort.
    var all_files = std.ArrayList(*HashedFile).init(gpa);
    defer all_files.deinit();

    var walker = try pkg_dir.walk(gpa);
    defer walker.deinit();

    {
        // The final hash will be a hash of each file hashed independently. This
        // allows hashing in parallel.
        var wait_group: WaitGroup = .{};
        // `computeHash` is called from a worker thread so there must not be
        // any waiting without working or a deadlock could occur.
        defer wait_group.waitAndWork();

        while (try walker.next()) |entry| {
            _ = filter; // TODO: apply filter rules here

            const kind: HashedFile.Kind = switch (entry.kind) {
                .directory => continue,
                .file => .file,
                .sym_link => .sym_link,
                else => return error.IllegalFileTypeInPackage,
            };

            if (std.mem.eql(u8, entry.path, build_zig_basename))
                f.has_build_zig = true;

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
            try f.thread_pool.spawn(workerHashFile, .{ pkg_dir.dir, hashed_file, &wait_group });

            try all_files.append(hashed_file);
        }
    }

    std.mem.sortUnstable(*HashedFile, all_files.items, {}, HashedFile.lessThan);

    var hasher = Manifest.Hash.init(.{});
    var any_failures = false;
    const eb = &f.error_bundle;
    for (all_files.items) |hashed_file| {
        hashed_file.failure catch |err| {
            any_failures = true;
            try eb.addRootErrorMessage(.{
                .msg = try eb.printString("unable to hash: {s}", .{@errorName(err)}),
                .src_loc = try eb.addSourceLocation(.{
                    .src_path = try eb.addString(hashed_file.fs_path),
                    .span_start = 0,
                    .span_end = 0,
                    .span_main = 0,
                }),
                .notes_len = 0,
            });
        };
        hasher.update(&hashed_file.hash);
    }
    if (any_failures) return error.FetchFailed;
    return hasher.finalResult();
}

fn workerHashFile(dir: fs.Dir, hashed_file: *HashedFile, wg: *WaitGroup) void {
    defer wg.finish();
    hashed_file.failure = hashFileFallible(dir, hashed_file);
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

const HashedFile = struct {
    fs_path: []const u8,
    normalized_path: []const u8,
    hash: Digest,
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

pub const Filter = struct {
    include_paths: std.StringArrayHashMapUnmanaged(void) = .{},

    /// sub_path is relative to the tarball root.
    pub fn includePath(self: Filter, sub_path: []const u8) bool {
        if (self.include_paths.count() == 0) return true;
        if (self.include_paths.contains("")) return true;
        if (self.include_paths.contains(sub_path)) return true;

        // Check if any included paths are parent directories of sub_path.
        var dirname = sub_path;
        while (std.fs.path.dirname(sub_path)) |next_dirname| {
            if (self.include_paths.contains(sub_path)) return true;
            dirname = next_dirname;
        }

        return false;
    }
};

const build_zig_basename = @import("../Package.zig").build_zig_basename;
const hex_multihash_len = 2 * Manifest.multihash_len;

// These are random bytes.
const package_hash_prefix_cached: [8]u8 = &.{ 0x53, 0x7e, 0xfa, 0x94, 0x65, 0xe9, 0xf8, 0x73 };
const package_hash_prefix_project: [8]u8 = &.{ 0xe1, 0x25, 0xee, 0xfa, 0xa6, 0x17, 0x38, 0xcc };

const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const assert = std.debug.assert;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const Manifest = @import("../Manifest.zig");
const Fetch = @This();
const main = @import("../main.zig");
const git = @import("../git.zig");
