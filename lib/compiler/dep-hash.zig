const usage_dep_hash =
    \\Usage: zig dep-hash [--list] [dep-name] [subdep...]
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

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const gpa = arena;

    const args = try std.process.argsAlloc(arena);
    const color: std.zig.Color = .auto;
    var list = false;
    var package_opt: ?[]const u8 = null;
    var build_root_path: ?[]const u8 = null;
    var override_global_cache_dir: ?[]const u8 = try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(arena);
    var subdeps = std.ArrayList([]const u8).init(arena);

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
                try subdeps.append(arg);
            } else {
                package_opt = arg;
            }
        }
    }

    var build_root = try std.zig.findBuildRoot(arena, .{
        .cwd_path = build_root_path,
        .hint = build_root_path == null,
    });
    defer build_root.deinit();

    var global_cache_package_directory: std.fs.Dir = l: {
        const p = try std.fs.path.join(arena, &.{
            override_global_cache_dir orelse try std.zig.introspect.resolveGlobalCacheDir(arena),
            "p",
        });

        break :l try std.fs.cwd().makeOpenPath(p, .{});
    };
    defer global_cache_package_directory.close();

    var manifest, var ast = std.zig.loadManifest(gpa, arena, .{
        .root_name = null,
        .dir = build_root.directory.handle,
        .color = color,
    }) catch |err| switch (err) {
        error.FileNotFound => fatal("no manifest found in build root", .{}),
        else => |e| return e,
    };
    defer {
        manifest.deinit(gpa);
        ast.deinit(gpa);
    }

    var dep_name = std.ArrayList(u8).init(gpa);
    defer dep_name.deinit();

    if (package_opt) |package| {
        if (package.len == 0) {
            fatal("package name must not be empty", .{});
        }
        const dep: std.zig.Manifest.Dependency = dep: {
            var dep = manifest.dependencies.get(package) orelse {
                fatal("there is no dependency named '{s}' in the manifest\n", .{package});
            };

            try dep_name.appendSlice(package);

            for (subdeps.items) |p| {
                if (dep.hash) |hash| {
                    var package_dir = global_cache_package_directory.openDir(hash, .{}) catch |e| switch (e) {
                        error.FileNotFound => fatal("{s} is not in the global cache (hash: {s})", .{
                            dep_name.items, hash,
                        }),
                        else => |err| return err,
                    };
                    defer package_dir.close();

                    const sub_manifest, _ = try std.zig.loadManifest(arena, arena, .{
                        .root_name = null,
                        .dir = package_dir,
                        .color = color,
                    });

                    dep = sub_manifest.dependencies.get(p) orelse {
                        fatal("{s} has no dependency named '{s}' in its manifest", .{
                            dep_name.items, p,
                        });
                    };
                    try dep_name.append('.');
                    try dep_name.appendSlice(p);
                } else switch (dep.location) {
                    .url => fatal("the hash for {s} is missing from the manifest.\n", .{
                        dep_name.items,
                    }),
                    .path => |path| fatal("{s} is a local dependency located at {s}\n", .{
                        dep_name.items, path,
                    }),
                }
            }

            break :dep dep;
        };

        const stdout = std.io.getStdOut().writer();

        if (dep.hash) |hash| {
            if (list) {
                var package_dir = global_cache_package_directory.openDir(hash, .{}) catch |e| switch (e) {
                    error.FileNotFound => fatal("{s} is not in the global cache (hash: {s})", .{
                        dep_name.items, hash,
                    }),
                    else => |err| return err,
                };
                defer package_dir.close();

                var sub_manifest, var sub_ast = std.zig.loadManifest(gpa, arena, .{
                    .root_name = null,
                    .dir = package_dir,
                    .color = color,
                }) catch |err| switch (err) {
                    error.FileNotFound => fatal("no manifest found in build root", .{}),
                    else => |e| return e,
                };
                defer {
                    sub_manifest.deinit(gpa);
                    sub_ast.deinit(gpa);
                }

                const prefix = prefix: {
                    var prefix_len: usize = package.len + 1;
                    for (subdeps.items) |subdep| {
                        prefix_len += subdep.len + 1;
                    }

                    const buffer = try arena.alloc(u8, prefix_len);

                    @memcpy(buffer[0..package.len], package);
                    buffer[package.len] = '.';

                    var i: usize = package.len + 1;
                    for (subdeps.items) |subdep| {
                        @memcpy(buffer[i..][0..subdep.len], subdep);
                        buffer[i + subdep.len] = '.';
                        i += subdep.len + 1;
                    }
                    break :prefix buffer;
                };

                try listDepHashes(prefix, sub_manifest);
            } else {
                try stdout.print("{s}\n", .{hash});
            }
        } else switch (dep.location) {
            .url => fatal("the hash for {s} is missing from the manifest.\n", .{package}),
            .path => |path| fatal("{s} is a local dependency located at {s}\n", .{ package, path }),
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
                .url => {
                    try stdout.print("{s}{s}    ", .{ parent_prefix, name });
                    try stdout.writeByteNTimes(' ', longest_name - name.len);
                    try stdout.writeAll("(missing)");
                },
                .path => |p| {
                    try stdout.print("{s}{s}    ", .{ parent_prefix, name });
                    try stdout.writeByteNTimes(' ', longest_name - name.len);
                    try stdout.print("{s} (local)\n", .{p});
                },
            }
        }
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
