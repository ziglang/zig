const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const fatal = std.process.fatal;
const Path = std.Build.Cache.Path;
const Directory = std.Build.Cache.Directory;
const Package = std.zig.Package;
const Allocator = std.mem.Allocator;

const usage =
    \\Usage: zig fetch [options] <url>
    \\Usage: zig fetch [options] <path>
    \\
    \\    Copy a package into the global cache and print its hash.
    \\    <url> must point to one of the following:
    \\      - A git+http / git+https server for the package
    \\      - A tarball file (with or without compression) containing
    \\        package source
    \\      - A git bundle file containing package source
    \\
    \\Examples:
    \\
    \\  zig fetch --save git+https://example.com/andrewrk/fun-example-tool.git
    \\  zig fetch --save https://example.com/andrewrk/fun-example-tool/archive/refs/heads/master.tar.gz
    \\
    \\Options:
    \\  -h, --help                    Print this help and exit
    \\  --global-cache-dir [path]     Override path to global Zig cache directory
    \\  --debug-hash                  Print verbose hash information to stdout
    \\  --save                        Add the fetched package to build.zig.zon
    \\  --save=[name]                 Add the fetched package to build.zig.zon as name
    \\  --save-exact                  Add the fetched package to build.zig.zon, storing the URL verbatim
    \\  --save-exact=[name]           Add the fetched package to build.zig.zon as name, storing the URL verbatim
    \\
;

pub const std_options: std.Options = .{
    .side_channels_mitigations = .none,
    .crypto_fork_safety = false,
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const gpa = arena;

    const args = try process.argsAlloc(arena);

    var zig_lib_directory: Directory = .{
        .handle = try std.fs.cwd().openDir(args[1], .{}),
    };
    defer zig_lib_directory.handle.close();

    var global_cache_directory: Directory = .{
        .handle = try std.fs.cwd().openDir(args[2], .{}),
    };
    defer global_cache_directory.handle.close();

    const color: std.zig.Color = .auto;
    const work_around_btrfs_bug = native_os == .linux and std.zig.EnvVar.ZIG_BTRFS_WORKAROUND.isSet();
    var opt_path_or_url: ?[]const u8 = null;
    var debug_hash: bool = false;
    var save: union(enum) {
        no,
        yes: ?[]const u8,
        exact: ?[]const u8,
    } = .no;

    {
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    const stdout = std.io.getStdOut().writer();
                    try stdout.writeAll(usage);
                    return process.cleanExit();
                } else if (mem.eql(u8, arg, "--debug-hash")) {
                    debug_hash = true;
                } else if (mem.eql(u8, arg, "--save")) {
                    save = .{ .yes = null };
                } else if (mem.startsWith(u8, arg, "--save=")) {
                    save = .{ .yes = arg["--save=".len..] };
                } else if (mem.eql(u8, arg, "--save-exact")) {
                    save = .{ .exact = null };
                } else if (mem.startsWith(u8, arg, "--save-exact=")) {
                    save = .{ .exact = arg["--save-exact=".len..] };
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

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = gpa });
    defer thread_pool.deinit();

    var http_client: std.http.Client = .{ .allocator = gpa };
    defer http_client.deinit();

    try http_client.initDefaultProxies(arena);

    var root_prog_node = std.Progress.start(.{
        .root_name = "Fetch",
    });
    defer root_prog_node.end();

    var job_queue: Package.Fetch.JobQueue = .{
        .http_client = &http_client,
        .thread_pool = &thread_pool,
        .global_cache = global_cache_directory,
        .recursive = false,
        .read_only = false,
        .debug_hash = debug_hash,
        .work_around_btrfs_bug = work_around_btrfs_bug,
    };
    defer job_queue.deinit();

    var fetch: Package.Fetch = .{
        .arena = std.heap.ArenaAllocator.init(gpa),
        .location = .{ .path_or_url = path_or_url },
        .location_tok = 0,
        .hash_tok = .none,
        .name_tok = 0,
        .lazy_status = .eager,
        .parent_package_root = undefined,
        .parent_manifest_ast = null,
        .prog_node = root_prog_node,
        .job_queue = &job_queue,
        .omit_missing_hash_error = true,
        .allow_missing_paths_field = false,
        .allow_missing_fingerprint = true,
        .allow_name_string = true,
        .use_latest_commit = true,

        .package_root = undefined,
        .error_bundle = undefined,
        .manifest = null,
        .manifest_ast = undefined,
        .computed_hash = undefined,
        .has_build_zig = false,
        .oom_flag = false,
        .latest_commit = null,
    };
    defer fetch.deinit();

    fetch.run() catch |err| switch (err) {
        error.OutOfMemory => fatal("out of memory", .{}),
        error.FetchFailed => {}, // error bundle checked below
    };

    if (fetch.error_bundle.root_list.items.len > 0) {
        var errors = try fetch.error_bundle.toOwnedBundle("");
        errors.renderToStdErr(color.renderOptions());
        process.exit(1);
    }

    const package_hash = fetch.computedPackageHash();
    const package_hash_slice = package_hash.toSlice();

    root_prog_node.end();
    root_prog_node = .{ .index = .none };

    const name = switch (save) {
        .no => {
            try std.io.getStdOut().writer().print("{s}\n", .{package_hash_slice});
            return process.cleanExit();
        },
        .yes, .exact => |name| name: {
            if (name) |n| break :name n;
            const fetched_manifest = fetch.manifest orelse
                fatal("unable to determine name; fetched package has no build.zig.zon file", .{});
            break :name fetched_manifest.name;
        },
    };

    const cwd_path = try process.getCwdAlloc(arena);

    var build_root = try Package.findBuildRoot(arena, .{
        .cwd_path = cwd_path,
    });
    defer build_root.deinit();

    // The name to use in case the manifest file needs to be created now.
    const init_root_name = std.fs.path.basename(build_root.directory.path orelse cwd_path);
    var manifest, var ast = try loadManifest(gpa, arena, zig_lib_directory, .{
        .root_name = try Package.sanitizeExampleName(arena, init_root_name),
        .dir = build_root.directory.handle,
        .color = color,
    });
    defer {
        manifest.deinit(gpa);
        ast.deinit(gpa);
    }

    var fixups: std.zig.Ast.Fixups = .{};
    defer fixups.deinit(gpa);

    var saved_path_or_url = path_or_url;

    if (fetch.latest_commit) |latest_commit| resolved: {
        const latest_commit_hex = try std.fmt.allocPrint(arena, "{}", .{latest_commit});

        var uri = try std.Uri.parse(path_or_url);

        if (uri.fragment) |fragment| {
            const target_ref = try fragment.toRawMaybeAlloc(arena);

            // the refspec may already be fully resolved
            if (std.mem.eql(u8, target_ref, latest_commit_hex)) break :resolved;

            std.log.info("resolved ref '{s}' to commit {s}", .{ target_ref, latest_commit_hex });

            // include the original refspec in a query parameter, could be used to check for updates
            uri.query = .{ .percent_encoded = try std.fmt.allocPrint(arena, "ref={%}", .{fragment}) };
        } else {
            std.log.info("resolved to commit {s}", .{latest_commit_hex});
        }

        // replace the refspec with the resolved commit SHA
        uri.fragment = .{ .raw = latest_commit_hex };

        switch (save) {
            .yes => saved_path_or_url = try std.fmt.allocPrint(arena, "{}", .{uri}),
            .no, .exact => {}, // keep the original URL
        }
    }

    const new_node_init = try std.fmt.allocPrint(arena,
        \\.{{
        \\            .url = "{}",
        \\            .hash = "{}",
        \\        }}
    , .{
        std.zig.fmtEscapes(saved_path_or_url),
        std.zig.fmtEscapes(package_hash_slice),
    });

    const new_node_text = try std.fmt.allocPrint(arena, ".{p_} = {s},\n", .{
        std.zig.fmtId(name), new_node_init,
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
                    if (mem.eql(u8, h, package_hash_slice) and mem.eql(u8, u, saved_path_or_url)) {
                        std.log.info("existing dependency named '{s}' is up-to-date", .{name});
                        process.exit(0);
                    }
                },
                .path => {},
            }
        }

        const location_replace = try std.fmt.allocPrint(
            arena,
            "\"{}\"",
            .{std.zig.fmtEscapes(saved_path_or_url)},
        );
        const hash_replace = try std.fmt.allocPrint(
            arena,
            "\"{}\"",
            .{std.zig.fmtEscapes(package_hash_slice)},
        );

        std.log.warn("overwriting existing dependency named '{s}'", .{name});
        try fixups.replace_nodes_with_string.put(gpa, dep.location_node, location_replace);
        if (dep.hash_node.unwrap()) |hash_node| {
            try fixups.replace_nodes_with_string.put(gpa, hash_node, hash_replace);
        } else {
            // https://github.com/ziglang/zig/issues/21690
        }
    } else if (manifest.dependencies.count() > 0) {
        // Add fixup for adding another dependency.
        const deps = manifest.dependencies.values();
        const last_dep_node = deps[deps.len - 1].node;
        try fixups.append_string_after_node.put(gpa, last_dep_node, new_node_text);
    } else if (manifest.dependencies_node.unwrap()) |dependencies_node| {
        // Add fixup for replacing the entire dependencies struct.
        try fixups.replace_nodes_with_string.put(gpa, dependencies_node, dependencies_init);
    } else {
        // Add fixup for adding dependencies struct.
        try fixups.append_string_after_node.put(gpa, manifest.version_node, dependencies_text);
    }

    var rendered = std.ArrayList(u8).init(gpa);
    defer rendered.deinit();
    try ast.renderToArrayList(&rendered, fixups);

    build_root.directory.handle.writeFile(.{ .sub_path = Package.Manifest.basename, .data = rendered.items }) catch |err| {
        fatal("unable to write {s} file: {s}", .{ Package.Manifest.basename, @errorName(err) });
    };

    return process.cleanExit();
}

const LoadManifestOptions = struct {
    root_name: []const u8,
    dir: fs.Dir,
    color: std.zig.Color,
};

fn loadManifest(
    gpa: Allocator,
    arena: Allocator,
    zig_lib_directory: Directory,
    options: LoadManifestOptions,
) !struct { Package.Manifest, std.zig.Ast } {
    const manifest_bytes = while (true) {
        break options.dir.readFileAllocOptions(
            arena,
            Package.Manifest.basename,
            Package.Manifest.max_bytes,
            null,
            1,
            0,
        ) catch |err| switch (err) {
            error.FileNotFound => {
                const fingerprint: Package.Fingerprint = .generate(options.root_name);
                var templates = Package.Templates.find(gpa, zig_lib_directory);
                defer templates.deinit(gpa);
                templates.write(arena, options.dir, options.root_name, Package.Manifest.basename, fingerprint) catch |e| {
                    fatal("unable to write {s}: {s}", .{
                        Package.Manifest.basename, @errorName(e),
                    });
                };
                continue;
            },
            else => |e| fatal("unable to load {s}: {s}", .{
                Package.Manifest.basename, @errorName(e),
            }),
        };
    };
    var ast = try std.zig.Ast.parse(gpa, manifest_bytes, .zon);
    errdefer ast.deinit(gpa);

    if (ast.errors.len > 0) {
        try std.zig.printAstErrorsToStderr(gpa, ast, Package.Manifest.basename, options.color);
        process.exit(2);
    }

    var manifest = try Package.Manifest.parse(gpa, ast, .{});
    errdefer manifest.deinit(gpa);

    if (manifest.errors.len > 0) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(gpa);
        defer wip_errors.deinit();

        const src_path = try wip_errors.addString(Package.Manifest.basename);
        try manifest.copyErrorsIntoBundle(ast, src_path, &wip_errors);

        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(gpa);
        error_bundle.renderToStdErr(options.color.renderOptions());

        process.exit(2);
    }
    return .{ manifest, ast };
}
