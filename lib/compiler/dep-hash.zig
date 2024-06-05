const usage_dep_hash =
    \\Usage: zig dep-hash [--list] [dep-name]
    \\
    \\   List the hashes of packages in the build.zig.zon manifest.
    \\
    \\Options:
    \\  --list                    List all package hashes
    \\  --build-root [path]       Set package root directory
    \\  --global-cache-dir [path] Override the global cache directory
    \\  -h, --help                Print this help and exit
    \\
    \\
;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const color: std.zig.Color = .auto;
    var list = false;
    var package_opt: ?[]const u8 = null;
    var build_root_path: ?[]const u8 = null;
    var override_global_cache_dir: ?[]const u8 = try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(arena);

    assert(args.len > 0);

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (arg[0] == '-') {
                if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                    const stdout = std.io.getStdOut();
                    try stdout.writeAll(usage_dep_hash);
                    return std.process.cleanExit();
                } else if (std.mem.eql(u8, arg, "--list")) {
                    list = true;
                } else if (std.mem.eql(u8, arg, "--build-root")) {
                    i += 1;
                    if (i >= args.len) fatal("build root expected after --build-root", .{});
                    build_root_path = args[i];
                } else if (std.mem.eql(u8, arg, "--global-cache-dir")) {
                    i += 1;
                    if (i >= args.len) fatal("cache directory expected after --global-cache-dir", .{});
                    override_global_cache_dir = args[i];
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else if (package_opt != null) {
                fatal("unexpected extra parameter: '{s}'", .{arg});
            } else {
                package_opt = arg;
            }
        }
    }

    if (build_root_path) |build_root| {
        if (!std.fs.path.isAbsolute(build_root)) {
            const cwd = try std.process.getCwdAlloc(arena);
            build_root_path = try std.fs.path.resolve(arena, &.{ cwd, build_root });
        }
    }

    var build_root = try std.zig.findBuildRoot(arena, .{
        .cwd_path = build_root_path,
    });
    defer build_root.deinit();

    var global_cache: std.Build.Cache.Directory = dir: {
        const path = override_global_cache_dir orelse try std.zig.introspect.resolveGlobalCacheDir(arena);
        const handle = std.fs.cwd().openDir(path, .{}) catch |err| {
            fatal("could not open global cache at '{s}': {s}", .{ path, @errorName(err) });
        };
        break :dir .{
            .handle = handle,
            .path = path,
        };
    };
    defer global_cache.handle.close();

    var manifest, var ast = try loadManifest(
        arena,
        build_root.directory,
        "",
        color,
    );
    defer {
        manifest.deinit(arena);
        ast.deinit(arena);
    }

    if (package_opt) |package| {
        if (package.len == 0) {
            fatal("package name must not be empty", .{});
        }
        const dep: std.zig.Manifest.Dependency = dep: {
            var iter = std.mem.tokenizeScalar(u8, package, '.');

            var dep = manifest.dependencies.get(iter.next().?) orelse {
                fatal("there is no dependency named '{s}' in the manifest", .{package});
            };

            var dep_name = iter.buffer[0 .. iter.index - 1];

            while (iter.next()) |p| {
                if (dep.hash) |hash| {
                    const sub_manifest, _ = try loadManifest(
                        arena,
                        global_cache,
                        hash,
                        color,
                    );

                    dep = sub_manifest.dependencies.get(p) orelse {
                        fatal("{s} has no dependency named '{s}' in its manifest", .{ dep_name, package });
                    };
                    dep_name = iter.buffer[0 .. iter.index - 1];
                } else switch (dep.location) {
                    .url => fatal("the hash for {s} is missing from the manifest", .{
                        dep_name,
                    }),
                    .path => |path| fatal("{s} is a local dependency located at {s}", .{
                        dep_name, path,
                    }),
                }
            }

            break :dep dep;
        };

        const stdout = std.io.getStdOut().writer();

        if (dep.hash) |hash| {
            if (list) {
                var sub_manifest, var sub_ast = try loadManifest(
                    arena,
                    global_cache,
                    hash,
                    color,
                );
                defer {
                    sub_manifest.deinit(arena);
                    sub_ast.deinit(arena);
                }

                const prefix = prefix: {
                    const buffer = try arena.alloc(u8, package.len + 1);
                    @memcpy(buffer[0..package.len], package);
                    buffer[buffer.len - 1] = '.';
                    break :prefix buffer;
                };

                try listDepHashes(prefix, sub_manifest);
            } else {
                try stdout.print("{s}\n", .{hash});
            }
        } else switch (dep.location) {
            .url => fatal("the hash for {s} is missing from the manifest", .{package}),
            .path => |path| fatal("{s} is a local dependency located at {s}", .{ package, path }),
        }
    } else {
        try listDepHashes("", manifest);
    }
}

fn listDepHashes(parent_prefix: []const u8, manifest: std.zig.Manifest) !void {
    assert(parent_prefix.len != 1);
    if (manifest.dependencies.count() == 0) {
        const name = if (parent_prefix.len > 0)
            parent_prefix[0 .. parent_prefix.len - 1]
        else
            manifest.name;

        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s} has no dependencies\n", .{name});
        return;
    }

    var deps = manifest.dependencies.iterator();
    while (deps.next()) |entry| {
        const stdout = std.io.getStdOut().writer();
        const name = entry.key_ptr.*;
        if (entry.value_ptr.hash) |hash| {
            try stdout.print("{s}{s}    {s}\n", .{ parent_prefix, name, hash });
        } else {
            switch (entry.value_ptr.location) {
                .url => try stdout.print("{s}{s}    {s}\n", .{
                    parent_prefix, name, "(missing)",
                }),
                .path => |p| try stdout.print("{s}{s}    {s} (local)\n", .{
                    parent_prefix, name, p,
                }),
            }
        }
    }
}

fn loadManifest(
    allocator: Allocator,
    root: std.Build.Cache.Directory,
    hash: []const u8,
    color: std.zig.Color,
) !struct { std.zig.Manifest, std.zig.Ast } {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const manifest_path = if (hash.len > 0)
        std.fmt.bufPrint(
            &buf,
            "p" ++ std.fs.path.sep_str ++ "{s}" ++ std.fs.path.sep_str ++ std.zig.Manifest.basename,
            .{hash},
        ) catch return error.NameTooLong
    else
        std.zig.Manifest.basename;

    const manifest_bytes = root.handle.readFileAllocOptions(
        allocator,
        manifest_path,
        std.zig.Manifest.max_bytes,
        null,
        .@"1",
        0,
    ) catch |err| {
        fatal("unable to load package manifest '{}{s}': {s}", .{
            root,
            manifest_path,
            @errorName(err),
        });
    };
    errdefer allocator.free(manifest_bytes);

    var ast = try std.zig.Ast.parse(allocator, manifest_bytes, .zon);
    errdefer ast.deinit(allocator);

    if (ast.errors.len > 0) {
        const file_path = try std.fmt.allocPrint(allocator, "{}{s}", .{
            root, manifest_path,
        });
        try std.zig.printAstErrorsToStderr(allocator, ast, file_path, color);
        std.process.exit(1);
    }

    var manifest = try std.zig.Manifest.parse(allocator, ast, .{
        .allow_missing_paths_field = true,
        .allow_missing_fingerprint = true,
        .allow_name_string = true,
    });
    errdefer manifest.deinit(allocator);

    if (manifest.errors.len > 0) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(allocator);
        defer wip_errors.deinit();

        const src_path = try wip_errors.printString("{}{s}", .{
            root,
            manifest_path,
        });
        try manifest.copyErrorsIntoBundle(ast, src_path, &wip_errors);

        var eb = try wip_errors.toOwnedBundle("");
        defer eb.deinit(allocator);
        eb.renderToStdErr(color.renderOptions());

        std.process.exit(1);
    }
    return .{ manifest, ast };
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
