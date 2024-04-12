const std = @import("std");
const builtin = @import("builtin");
const EnvVar = zig.EnvVar;
const fatal = zig.fatal;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const native_os = builtin.os.tag;
const ThreadPool = std.Thread.Pool;
const zig = std.zig;
const Fetch = zig.package.Fetch;
const Manifest = zig.package.Manifest;

const Cache = std.Build.Cache;

const usage_fetch =
    \\Usage: zig fetch [options] <url>
    \\Usage: zig fetch [options] <path>
    \\
    \\    Copy a package into the global cache and print its hash.
    \\
    \\Options:
    \\  -h, --help                    Print this help and exit
    \\  --global-cache-dir [path]     Override path to global Zig cache directory
    \\  --debug-hash                  Print verbose hash information to stdout
    \\  --save                        Add the fetched package to build.zig.zon
    \\  --save=[name]                 Add the fetched package to build.zig.zon as name
    \\
;

const color: zig.Color = .auto;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    const work_around_btrfs_bug = native_os == .linux and
        EnvVar.ZIG_BTRFS_WORKAROUND.isSet();
    var opt_path_or_url: ?[]const u8 = null;
    var override_global_cache_dir: ?[]const u8 = try EnvVar.ZIG_GLOBAL_CACHE_DIR.get(arena);
    var debug_hash: bool = false;
    var save: union(enum) { no, yes, name: []const u8 } = .no;

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    const stdout = io.getStdOut().writer();
                    try stdout.writeAll(usage_fetch);
                    return std.process.cleanExit();
                } else if (mem.eql(u8, arg, "--global-cache-dir")) {
                    if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                    i += 1;
                    override_global_cache_dir = args[i];
                } else if (mem.eql(u8, arg, "--debug-hash")) {
                    debug_hash = true;
                } else if (mem.eql(u8, arg, "--save")) {
                    save = .yes;
                } else if (mem.startsWith(u8, arg, "--save=")) {
                    save = .{ .name = arg["--save=".len..] };
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else if (opt_path_or_url != null) {
                fatal("unexpected extra parameter: '{s}'", .{arg});
            } else {
                opt_path_or_url = arg;
            }
        }
    }

    const path_or_url = opt_path_or_url orelse fatal("missing url or path parameter", .{});

    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(.{ .allocator = arena });
    defer thread_pool.deinit();

    var http_client: std.http.Client = .{ .allocator = arena };
    defer http_client.deinit();

    try http_client.initDefaultProxies(arena);

    var progress: std.Progress = .{ .dont_print_on_dumb = true };
    const root_prog_node = progress.start("Fetch", 0);
    defer root_prog_node.end();

    var global_cache_directory: std.Build.Cache.Directory = l: {
        const p = override_global_cache_dir orelse try zig.introspect.resolveGlobalCacheDir(arena);
        break :l .{
            .handle = try std.fs.cwd().makeOpenPath(p, .{}),
            .path = p,
        };
    };
    defer global_cache_directory.handle.close();

    var job_queue: Fetch.JobQueue = .{
        .http_client = &http_client,
        .thread_pool = &thread_pool,
        .global_cache = global_cache_directory,
        .recursive = false,
        .read_only = false,
        .debug_hash = debug_hash,
        .work_around_btrfs_bug = work_around_btrfs_bug,
    };
    defer job_queue.deinit();

    var fetch: Fetch = .{
        .arena = std.heap.ArenaAllocator.init(arena),
        .location = .{ .path_or_url = path_or_url },
        .location_tok = 0,
        .hash_tok = 0,
        .name_tok = 0,
        .lazy_status = .eager,
        .parent_package_root = undefined,
        .parent_manifest_ast = null,
        .prog_node = root_prog_node,
        .job_queue = &job_queue,
        .omit_missing_hash_error = true,
        .allow_missing_paths_field = false,

        .package_root = undefined,
        .error_bundle = undefined,
        .manifest = null,
        .manifest_ast = undefined,
        .actual_hash = undefined,
        .has_build_zig = false,
        .oom_flag = false,

        .module = null,
    };
    defer fetch.deinit();

    fetch.run() catch |err| switch (err) {
        error.OutOfMemory => fatal("out of memory", .{}),
        error.FetchFailed => {}, // error bundle checked below
    };

    if (fetch.error_bundle.root_list.items.len > 0) {
        var errors = try fetch.error_bundle.toOwnedBundle("");
        errors.renderToStdErr(color.renderOptions());
        std.process.exit(1);
    }

    const hex_digest = Manifest.hexDigest(fetch.actual_hash);

    progress.done = true;
    progress.refresh();

    const name = switch (save) {
        .no => {
            try io.getStdOut().writeAll(hex_digest ++ "\n");
            return std.process.cleanExit();
        },
        .yes => n: {
            const fetched_manifest = fetch.manifest orelse
                fatal("unable to determine name; fetched package has no build.zig.zon file", .{});
            break :n fetched_manifest.name;
        },
        .name => |n| n,
    };

    const cwd_path = try std.process.getCwdAlloc(arena);

    var build_root = try std.zig.introspect.findBuildRoot(arena, .{
        .cwd_path = cwd_path,
    });
    defer build_root.deinit();

    // The name to use in case the manifest file needs to be created now.
    const init_root_name = std.fs.path.basename(build_root.directory.path orelse cwd_path);
    var manifest, var ast = try loadManifest(arena, arena, .{
        .root_name = init_root_name,
        .dir = build_root.directory.handle,
        .color = color,
    });
    defer {
        manifest.deinit(arena);
        ast.deinit(arena);
    }

    var fixups: zig.Ast.Fixups = .{};
    defer fixups.deinit(arena);

    const new_node_init = try std.fmt.allocPrint(arena,
        \\.{{
        \\            .url = "{}",
        \\            .hash = "{}",
        \\        }}
    , .{
        zig.fmtEscapes(path_or_url),
        zig.fmtEscapes(&hex_digest),
    });

    const new_node_text = try std.fmt.allocPrint(arena, ".{p_} = {s},\n", .{
        zig.fmtId(name), new_node_init,
    });

    const dependencies_init = try std.fmt.allocPrint(arena, ".{{\n        {s}    }}", .{
        new_node_text,
    });

    const dependencies_text = try std.fmt.allocPrint(arena, ".dependencies = {s},\n", .{
        dependencies_init,
    });

    if (manifest.dependencies.get(name)) |dep| {
        if (dep.hash) |h| {
            switch (dep.location) {
                .url => |u| {
                    if (mem.eql(u8, h, &hex_digest) and mem.eql(u8, u, path_or_url)) {
                        std.log.info("existing dependency named '{s}' is up-to-date", .{name});
                        return std.process.cleanExit();
                    }
                },
                .path => {},
            }
        }
        std.log.warn("overwriting existing dependency named '{s}'", .{name});
        try fixups.replace_nodes_with_string.put(arena, dep.node, new_node_init);
    } else if (manifest.dependencies.count() > 0) {
        // Add fixup for adding another dependency.
        const deps = manifest.dependencies.values();
        const last_dep_node = deps[deps.len - 1].node;
        try fixups.append_string_after_node.put(arena, last_dep_node, new_node_text);
    } else if (manifest.dependencies_node != 0) {
        // Add fixup for replacing the entire dependencies struct.
        try fixups.replace_nodes_with_string.put(arena, manifest.dependencies_node, dependencies_init);
    } else {
        // Add fixup for adding dependencies struct.
        try fixups.append_string_after_node.put(arena, manifest.version_node, dependencies_text);
    }

    var rendered = std.ArrayList(u8).init(arena);
    defer rendered.deinit();
    try ast.renderToArrayList(&rendered, fixups);

    build_root.directory.handle.writeFile(Manifest.basename, rendered.items) catch |err| {
        fatal("unable to write {s} file: {s}", .{ Manifest.basename, @errorName(err) });
    };

    return std.process.cleanExit();
}

const LoadManifestOptions = struct {
    root_name: []const u8,
    dir: std.fs.Dir,
    color: zig.Color,
};

fn loadManifest(
    gpa: mem.Allocator,
    arena: mem.Allocator,
    options: LoadManifestOptions,
) !struct { Manifest, zig.Ast } {
    const manifest_bytes = while (true) {
        break options.dir.readFileAllocOptions(
            arena,
            Manifest.basename,
            Manifest.max_bytes,
            null,
            1,
            0,
        ) catch |err| switch (err) {
            error.FileNotFound => {
                var templates = zig.introspect.findTemplates(gpa, arena);
                defer templates.deinit();

                templates.write(arena, options.dir, options.root_name, Manifest.basename) catch |e| {
                    fatal("unable to write {s}: {s}", .{
                        Manifest.basename, @errorName(e),
                    });
                };
                continue;
            },
            else => |e| fatal("unable to load {s}: {s}", .{
                Manifest.basename, @errorName(e),
            }),
        };
    };
    var ast = try zig.Ast.parse(gpa, manifest_bytes, .zon);
    errdefer ast.deinit(gpa);

    if (ast.errors.len > 0) {
        try std.zig.printAstErrorsToStderr(gpa, ast, Manifest.basename, options.color);
        std.process.exit(2);
    }

    var manifest = try Manifest.parse(gpa, ast, .{});
    errdefer manifest.deinit(gpa);

    if (manifest.errors.len > 0) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(gpa);
        defer wip_errors.deinit();

        const src_path = try wip_errors.addString(Manifest.basename);
        try manifest.copyErrorsIntoBundle(ast, src_path, &wip_errors);

        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(gpa);
        error_bundle.renderToStdErr(options.color.renderOptions());

        std.process.exit(2);
    }
    return .{ manifest, ast };
}
