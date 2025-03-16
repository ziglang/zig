const usage_dep_hash =
    \\Usage: zig dep-hash [--list] [dep-name] [subdep...]
    \\
    \\   List the hashes of packages in the build.zig.zon manifest.
    \\
    \\Options:
    \\  --graph                   Print dependency graph
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
    var mode: enum { graph, list, single } = .single;
    var build_root_path: ?[]const u8 = null;
    var override_global_cache_dir: ?[]const u8 = try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(arena);
    var dep_chain = std.ArrayList([]const u8).init(arena);

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
                    mode = .list;
                } else if (std.mem.eql(u8, arg, "--graph")) {
                    mode = .graph;
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
            } else {
                try dep_chain.append(arg);
            }
        }
    }

    if (dep_chain.items.len == 0 and mode != .list) mode = .graph;

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
        std.zig.Manifest.basename,
        color,
        true,
    );
    defer {
        manifest.deinit(arena);
        ast.deinit(arena);
    }

    const dep_name = try std.mem.join(arena, ".", dep_chain.items);
    defer arena.free(dep_name);

    var man = try loadTransitiveDepManifest(
        arena,
        global_cache,
        build_root.directory,
        manifest,
        dep_chain.items[0 .. dep_chain.items.len - @intFromBool(mode == .single)],
        dep_name,
        color,
    );
    defer man.deinit(arena);

    const stdout = std.io.getStdOut().writer();

    switch (mode) {
        .graph => try graph(
            arena,
            stdout,
            global_cache,
            build_root.directory,
            man,
            color,
        ),
        .list => try listDepHashes(man),
        .single => {
            assert(dep_chain.items.len > 0);
            const dep = man.dependencies.get(dep_chain.items[dep_chain.items.len - 1]) orelse {
                const name = dep_chain.items[dep_chain.items.len];
                fatal("{s} has no dependency named '{s}' in the manifest", .{
                    dep_name[0 .. dep_name.len - name.len],
                    name,
                });
            };
            if (dep.hash) |hash| {
                try stdout.print("{s}\n", .{hash});
            } else switch (dep.location) {
                .url => fatal("the hash for {s} is missing from the manifest", .{dep_name}),
                .path => fatal("{s} is a local dependency", .{dep_name}),
            }
        },
    }
}

fn graph(
    allocator: Allocator,
    writer: anytype,
    global_cache: std.Build.Cache.Directory,
    build_root: std.Build.Cache.Directory,
    manifest: std.zig.Manifest,
    color: std.zig.Color,
) !void {
    try writer.print("{s}\n", .{manifest.name});
    try graphInner(
        allocator,
        writer,
        global_cache,
        build_root,
        manifest,
        0,
        0,
        color,
    );
}

fn graphInner(
    allocator: Allocator,
    writer: anytype,
    global_cache: std.Build.Cache.Directory,
    build_root: std.Build.Cache.Directory,
    manifest: std.zig.Manifest,
    line_count: usize,
    indent: usize,
    color: std.zig.Color,
) !void {
    var deps = manifest.dependencies.iterator();

    const longest_name: usize = length: {
        var len: usize = 0;
        while (deps.next()) |entry| {
            len = @max(len, entry.key_ptr.len);
        }
        break :length len;
    };

    deps.reset();

    while (deps.next()) |entry| {
        const name = entry.key_ptr.*;
        const dep = entry.value_ptr.*;

        for (0..line_count) |_| {
            try writer.writeAll("│  ");
        }

        try writer.writeByteNTimes(' ', 3 * (indent - line_count));

        const last = deps.index > manifest.dependencies.entries.len - 1;
        if (last) {
            try writer.print("└─ {s} ", .{name});
        } else {
            try writer.print("├─ {s} ", .{name});
        }

        try writer.writeByteNTimes(' ', longest_name - name.len);

        if (dep.hash) |hash|
            try writer.print("{s}\n", .{hash})
        else switch (dep.location) {
            .url => try writer.writeAll("(missing)\n"),
            .path => |p| try writer.print("{s} (local)\n", .{p}),
        }

        var submanifest, var ast = loadDepManifest(
            allocator,
            global_cache,
            build_root,
            dep,
            name,
            color,
            false,
        ) catch |err| switch (err) {
            error.FileNotFound => {
                continue;
            },
            else => |e| return e,
        };
        ast.deinit(allocator);
        defer submanifest.deinit(allocator);

        try graphInner(
            allocator,
            writer,
            global_cache,
            build_root,
            submanifest,
            line_count + @intFromBool(!last),
            indent + 1,
            color,
        );
    }
}

fn listDepHashes(manifest: std.zig.Manifest) !void {
    if (manifest.dependencies.count() == 0) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s} has no dependencies\n", .{manifest.name});
        return;
    }

    var longest_name: usize = 0;
    var deps = manifest.dependencies.iterator();

    while (deps.next()) |entry| {
        longest_name = @max(longest_name, entry.key_ptr.len);
    }

    deps.reset();
    while (deps.next()) |entry| {
        const stdout = std.io.getStdOut().writer();
        const name = entry.key_ptr.*;
        if (entry.value_ptr.hash) |hash| {
            try stdout.print("{s}    ", .{name});
            try stdout.writeByteNTimes(' ', longest_name - name.len);
            try stdout.print("{s}\n", .{hash});
        } else {
            switch (entry.value_ptr.location) {
                .url => {
                    try stdout.print("{s}    ", .{name});
                    try stdout.writeByteNTimes(' ', longest_name - name.len);
                    try stdout.writeAll("(missing)");
                },
                .path => |p| {
                    try stdout.print("{s}    ", .{name});
                    try stdout.writeByteNTimes(' ', longest_name - name.len);
                    try stdout.print("{s} (local)\n", .{p});
                },
            }
        }
    }
}

fn loadTransitiveDepManifest(
    allocator: Allocator,
    global_cache: std.Build.Cache.Directory,
    build_root: std.Build.Cache.Directory,
    root_manifest: std.zig.Manifest,
    dep_chain: []const []const u8,
    dep_name: []const u8,
    color: std.zig.Color,
) !std.zig.Manifest {
    var manifest = root_manifest;
    var dep_name_len: usize = 0;

    for (dep_chain) |p| {
        if (p.len == 0) {
            fatal("package name must not be empty", .{});
        }

        const dep = manifest.dependencies.get(p) orelse {
            fatal("{s} has no dependency named '{s}' in the manifest", .{
                if (dep_name_len == 0) "the root package" else dep_name[0..dep_name_len],
                p,
            });
        };

        dep_name_len += p.len;

        manifest, var sub_ast = try loadDepManifest(
            allocator,
            global_cache,
            build_root,
            dep,
            dep_name[0..dep_name_len],
            color,
            true,
        );
        sub_ast.deinit(allocator);

        dep_name_len += 1;
    }
    return manifest;
}

fn loadDepManifest(
    allocator: Allocator,
    global_cache: std.Build.Cache.Directory,
    build_root: std.Build.Cache.Directory,
    dep: std.zig.Manifest.Dependency,
    dep_name: []const u8,
    color: std.zig.Color,
    required: bool,
) !struct { std.zig.Manifest, std.zig.Ast } {
    if (dep.hash) |hash| {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const manifest_path = std.fmt.bufPrint(
            &buf,
            "p" ++ std.fs.path.sep_str ++ "{s}" ++ std.fs.path.sep_str ++ std.zig.Manifest.basename,
            .{hash},
        ) catch return error.NameTooLong;

        return try loadManifest(
            allocator,
            global_cache,
            manifest_path,
            color,
            required,
        );
    } else switch (dep.location) {
        .url => fatal("the hash for {s} is missing from the manifest", .{
            dep_name,
        }),
        .path => |path| {
            const handle = build_root.handle.openDir(path, .{}) catch |e| switch (e) {
                error.FileNotFound => fatal("local dependency {s} does not exist", .{dep_name}),
                else => |err| return err,
            };
            const root_path = try build_root.join(allocator, &.{path});
            defer allocator.free(root_path);
            var root: std.Build.Cache.Directory = .{ .handle = handle, .path = root_path };
            defer root.closeAndFree(allocator);
            return try loadManifest(
                allocator,
                root,
                std.zig.Manifest.basename,
                color,
                required,
            );
        },
    }
}

fn loadManifest(
    allocator: Allocator,
    root: std.Build.Cache.Directory,
    manifest_path: []const u8,
    color: std.zig.Color,
    required: bool,
) !struct { std.zig.Manifest, std.zig.Ast } {
    const manifest_bytes = root.handle.readFileAllocOptions(
        allocator,
        manifest_path,
        std.zig.Manifest.max_bytes,
        null,
        .@"1",
        0,
    ) catch |err| {
        if (!required) {
            if (err == error.FileNotFound) return error.FileNotFound;
        }
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
