const builtin = @import("builtin");

const std = @import("std");
const mem = std.mem;
const fatal = std.process.fatal;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Step = std.Build.Step;

pub const root = @import("@build");
pub const dependencies = @import("@dependencies");

pub const std_options: std.Options = .{
    .side_channels_mitigations = .none,
    .http_disable_tls = true,
    .crypto_fork_safety = false,
};

comptime {
    assert(builtin.single_threaded);
}

pub fn main() !void {
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();
    const arena = single_threaded_arena.allocator();

    const args = try std.process.argsAlloc(arena);

    // skip my own exe name
    var arg_idx: usize = 1;

    const zig_exe = nextArg(args, &arg_idx) orelse fatal("missing zig compiler path", .{});
    const zig_lib_dir = nextArg(args, &arg_idx) orelse fatal("missing zig lib directory path", .{});
    const cache_root = nextArg(args, &arg_idx) orelse fatal("missing cache root directory path", .{});
    const global_cache_root = nextArg(args, &arg_idx) orelse fatal("missing global cache root directory path", .{});
    const build_root = nextArg(args, &arg_idx) orelse fatal("missing build root directory path", .{});

    const zig_lib_directory: std.Build.Cache.Directory = .{
        .path = zig_lib_dir,
        .handle = try std.fs.cwd().openDir(zig_lib_dir, .{}),
    };

    const build_root_directory: std.Build.Cache.Directory = .{
        .path = build_root,
        .handle = try std.fs.cwd().openDir(build_root, .{}),
    };

    const local_cache_directory: std.Build.Cache.Directory = .{
        .path = cache_root,
        .handle = try std.fs.cwd().makeOpenPath(cache_root, .{}),
    };

    const global_cache_directory: std.Build.Cache.Directory = .{
        .path = global_cache_root,
        .handle = try std.fs.cwd().makeOpenPath(global_cache_root, .{}),
    };

    var graph: std.Build.Graph = .{
        .arena = arena,
        .cache = .{
            .gpa = arena,
            .manifest_dir = try local_cache_directory.handle.makeOpenPath("h", .{}),
        },
        .zig_exe = zig_exe,
        .env_map = try std.process.getEnvMap(arena),
        .global_cache_root = global_cache_directory,
        .zig_lib_directory = zig_lib_directory,
        .host = .{
            .query = .{},
            .result = try std.zig.system.resolveTargetQuery(.{}),
        },
    };

    graph.cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
    graph.cache.addPrefix(build_root_directory);
    graph.cache.addPrefix(local_cache_directory);
    graph.cache.addPrefix(global_cache_directory);
    graph.cache.hash.addBytes(builtin.zig_version_string);

    const builder = try std.Build.create(
        &graph,
        build_root_directory,
        local_cache_directory,
        dependencies.root_deps,
    );

    var install_prefix: ?std.Build.Cache.Path = null;
    var install_paths: std.Build.InstallPaths = .{};

    while (nextArg(args, &arg_idx)) |arg| {
        if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2..];
            if (option_contents.len == 0)
                fatal("expected option name after '-D'", .{});
            if (mem.indexOfScalar(u8, option_contents, '=')) |name_end| {
                const option_name = option_contents[0..name_end];
                const option_value = option_contents[name_end + 1 ..];
                if (try builder.addUserInputOption(option_name, option_value))
                    fatal("  access the help menu with 'zig build -h'", .{});
            } else {
                if (try builder.addUserInputFlag(option_contents))
                    fatal("  access the help menu with 'zig build -h'", .{});
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--prefix")) {
                install_prefix = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--prefix-lib-dir")) {
                install_paths.lib_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--prefix-exe-dir")) {
                install_paths.exe_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--prefix-include-dir")) {
                install_paths.include_dir = nextArgOrFatal(args, &arg_idx);
            } else {
                fatal("unrecognized argument: '{s}'", .{arg});
            }
        } else {
            fatal("unrecognized argument: '{s}'", .{arg});
        }
    }

    builder.resolveInstallPrefix(install_prefix, install_paths);
    try builder.runBuild(root);
    createModuleDependencies(builder) catch @panic("OOM");

    try std.io.getStdOut().writeAll("TODO\n");
}

fn nextArg(args: []const [:0]const u8, idx: *usize) ?[:0]const u8 {
    if (idx.* >= args.len) return null;
    defer idx.* += 1;
    return args[idx.*];
}

fn nextArgOrFatal(args: []const [:0]const u8, idx: *usize) [:0]const u8 {
    return nextArg(args, idx) orelse fatal("expected argument after '{s}'", .{args[idx.* - 1]});
}

/// Starting from all top-level steps in `b`, traverses the entire step graph
/// and adds all step dependencies implied by module graphs.
fn createModuleDependencies(b: *std.Build) Allocator.Error!void {
    const arena = b.graph.arena;

    var all_steps: std.AutoArrayHashMapUnmanaged(*Step, void) = .empty;
    var next_step_idx: usize = 0;

    try all_steps.ensureUnusedCapacity(arena, b.top_level_steps.count());
    for (b.top_level_steps.values()) |tls| {
        all_steps.putAssumeCapacityNoClobber(&tls.step, {});
    }

    while (next_step_idx < all_steps.count()) {
        const step = all_steps.keys()[next_step_idx];
        next_step_idx += 1;

        // Set up any implied dependencies for this step. It's important that we do this first, so
        // that the loop below discovers steps implied by the module graph.
        try createModuleDependenciesForStep(step);

        try all_steps.ensureUnusedCapacity(arena, step.dependencies.items.len);
        for (step.dependencies.items) |other_step| {
            all_steps.putAssumeCapacity(other_step, {});
        }
    }
}

/// If the given `Step` is a `Step.Compile`, adds any dependencies for that step which
/// are implied by the module graph rooted at `step.cast(Step.Compile).?.root_module`.
fn createModuleDependenciesForStep(step: *Step) Allocator.Error!void {
    const root_module = if (step.cast(Step.Compile)) |cs| root: {
        break :root cs.root_module;
    } else return; // not a compile step so no module dependencies

    // Starting from `root_module`, discover all modules in this graph.
    const modules = root_module.getGraph().modules;

    // For each of those modules, set up the implied step dependencies.
    for (modules) |mod| {
        if (mod.root_source_file) |lp| lp.addStepDependencies(step);
        for (mod.include_dirs.items) |include_dir| switch (include_dir) {
            .path,
            .path_system,
            .path_after,
            .framework_path,
            .framework_path_system,
            => |lp| lp.addStepDependencies(step),

            .other_step => |other| {
                other.getEmittedIncludeTree().addStepDependencies(step);
                step.dependOn(&other.step);
            },

            .config_header_step => |other| step.dependOn(&other.step),
        };
        for (mod.lib_paths.items) |lp| lp.addStepDependencies(step);
        for (mod.rpaths.items) |rpath| switch (rpath) {
            .lazy_path => |lp| lp.addStepDependencies(step),
            .special => {},
        };
        for (mod.link_objects.items) |link_object| switch (link_object) {
            .static_path,
            .assembly_file,
            => |lp| lp.addStepDependencies(step),
            .other_step => |other| step.dependOn(&other.step),
            .system_lib => {},
            .c_source_file => |source| source.file.addStepDependencies(step),
            .c_source_files => |source_files| source_files.root.addStepDependencies(step),
            .win32_resource_file => |rc_source| {
                rc_source.file.addStepDependencies(step);
                for (rc_source.include_paths) |lp| lp.addStepDependencies(step);
            },
        };
    }
}
