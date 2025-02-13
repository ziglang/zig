const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const io = std.io;
const fmt = std.fmt;
const mem = std.mem;
const process = std.process;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Step = std.Build.Step;
const Watch = std.Build.Watch;
const Fuzz = std.Build.Fuzz;
const Allocator = std.mem.Allocator;
const fatal = std.process.fatal;
const runner = @This();

pub const root = @import("@build");
pub const dependencies = @import("@dependencies");

pub const std_options: std.Options = .{
    .side_channels_mitigations = .none,
    .http_disable_tls = true,
    .crypto_fork_safety = false,
};

pub fn main() !void {
    // Here we use an ArenaAllocator backed by a page allocator because a build is a short-lived,
    // one shot program. We don't need to waste time freeing memory and finding places to squish
    // bytes into. So we free everything all at once at the very end.
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();

    var thread_safe_arena: std.heap.ThreadSafeAllocator = .{
        .child_allocator = single_threaded_arena.allocator(),
    };
    const arena = thread_safe_arena.allocator();

    const args = try process.argsAlloc(arena);

    // skip my own exe name
    var arg_idx: usize = 1;

    const zig_exe = nextArg(args, &arg_idx) orelse fatal("missing zig compiler path", .{});
    const zig_lib_dir = nextArg(args, &arg_idx) orelse fatal("missing zig lib directory path", .{});
    const build_root = nextArg(args, &arg_idx) orelse fatal("missing build root directory path", .{});
    const cache_root = nextArg(args, &arg_idx) orelse fatal("missing cache root directory path", .{});
    const global_cache_root = nextArg(args, &arg_idx) orelse fatal("missing global cache root directory path", .{});

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
        .env_map = try process.getEnvMap(arena),
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

    var targets = ArrayList([]const u8).init(arena);
    var debug_log_scopes = ArrayList([]const u8).init(arena);
    var thread_pool_options: std.Thread.Pool.Options = .{ .allocator = arena };

    var install_prefix: ?[]const u8 = null;
    var dir_list = std.Build.DirList{};
    var summary: ?Summary = null;
    var max_rss: u64 = 0;
    var skip_oom_steps = false;
    var color: Color = .auto;
    var prominent_compile_errors = false;
    var help_menu = false;
    var steps_menu = false;
    var output_tmp_nonce: ?[16]u8 = null;
    var watch = false;
    var fuzz = false;
    var debounce_interval_ms: u16 = 50;
    var listen_port: u16 = 0;

    while (nextArg(args, &arg_idx)) |arg| {
        if (mem.startsWith(u8, arg, "-Z")) {
            if (arg.len != 18) fatalWithHint("bad argument: '{s}'", .{arg});
            output_tmp_nonce = arg[2..18].*;
        } else if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2..];
            if (option_contents.len == 0)
                fatalWithHint("expected option name after '-D'", .{});
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
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                help_menu = true;
            } else if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--prefix")) {
                install_prefix = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--list-steps")) {
                steps_menu = true;
            } else if (mem.startsWith(u8, arg, "-fsys=")) {
                const name = arg["-fsys=".len..];
                graph.system_library_options.put(arena, name, .user_enabled) catch @panic("OOM");
            } else if (mem.startsWith(u8, arg, "-fno-sys=")) {
                const name = arg["-fno-sys=".len..];
                graph.system_library_options.put(arena, name, .user_disabled) catch @panic("OOM");
            } else if (mem.eql(u8, arg, "--release")) {
                builder.release_mode = .any;
            } else if (mem.startsWith(u8, arg, "--release=")) {
                const text = arg["--release=".len..];
                builder.release_mode = std.meta.stringToEnum(std.Build.ReleaseMode, text) orelse {
                    fatalWithHint("expected [off|any|fast|safe|small] in '{s}', found '{s}'", .{
                        arg, text,
                    });
                };
            } else if (mem.eql(u8, arg, "--prefix-lib-dir")) {
                dir_list.lib_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--prefix-exe-dir")) {
                dir_list.exe_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--prefix-include-dir")) {
                dir_list.include_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--sysroot")) {
                builder.sysroot = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--maxrss")) {
                const max_rss_text = nextArgOrFatal(args, &arg_idx);
                max_rss = std.fmt.parseIntSizeSuffix(max_rss_text, 10) catch |err| {
                    std.debug.print("invalid byte size: '{s}': {s}\n", .{
                        max_rss_text, @errorName(err),
                    });
                    process.exit(1);
                };
            } else if (mem.eql(u8, arg, "--skip-oom-steps")) {
                skip_oom_steps = true;
            } else if (mem.eql(u8, arg, "--search-prefix")) {
                const search_prefix = nextArgOrFatal(args, &arg_idx);
                builder.addSearchPrefix(search_prefix);
            } else if (mem.eql(u8, arg, "--libc")) {
                builder.libc_file = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--color")) {
                const next_arg = nextArg(args, &arg_idx) orelse
                    fatalWithHint("expected [auto|on|off] after '{s}'", .{arg});
                color = std.meta.stringToEnum(Color, next_arg) orelse {
                    fatalWithHint("expected [auto|on|off] after '{s}', found '{s}'", .{
                        arg, next_arg,
                    });
                };
            } else if (mem.eql(u8, arg, "--summary")) {
                const next_arg = nextArg(args, &arg_idx) orelse
                    fatalWithHint("expected [all|new|failures|none] after '{s}'", .{arg});
                summary = std.meta.stringToEnum(Summary, next_arg) orelse {
                    fatalWithHint("expected [all|new|failures|none] after '{s}', found '{s}'", .{
                        arg, next_arg,
                    });
                };
            } else if (mem.eql(u8, arg, "--seed")) {
                const next_arg = nextArg(args, &arg_idx) orelse
                    fatalWithHint("expected u32 after '{s}'", .{arg});
                graph.random_seed = std.fmt.parseUnsigned(u32, next_arg, 0) catch |err| {
                    fatal("unable to parse seed '{s}' as unsigned 32-bit integer: {s}\n", .{
                        next_arg, @errorName(err),
                    });
                };
            } else if (mem.eql(u8, arg, "--debounce")) {
                const next_arg = nextArg(args, &arg_idx) orelse
                    fatalWithHint("expected u16 after '{s}'", .{arg});
                debounce_interval_ms = std.fmt.parseUnsigned(u16, next_arg, 0) catch |err| {
                    fatal("unable to parse debounce interval '{s}' as unsigned 16-bit integer: {s}\n", .{
                        next_arg, @errorName(err),
                    });
                };
            } else if (mem.eql(u8, arg, "--port")) {
                const next_arg = nextArg(args, &arg_idx) orelse
                    fatalWithHint("expected u16 after '{s}'", .{arg});
                listen_port = std.fmt.parseUnsigned(u16, next_arg, 10) catch |err| {
                    fatal("unable to parse port '{s}' as unsigned 16-bit integer: {s}\n", .{
                        next_arg, @errorName(err),
                    });
                };
            } else if (mem.eql(u8, arg, "--debug-log")) {
                const next_arg = nextArgOrFatal(args, &arg_idx);
                try debug_log_scopes.append(next_arg);
            } else if (mem.eql(u8, arg, "--debug-pkg-config")) {
                builder.debug_pkg_config = true;
            } else if (mem.eql(u8, arg, "--debug-rt")) {
                graph.debug_compiler_runtime_libs = true;
            } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                builder.debug_compile_errors = true;
            } else if (mem.eql(u8, arg, "--system")) {
                // The usage text shows another argument after this parameter
                // but it is handled by the parent process. The build runner
                // only sees this flag.
                graph.system_package_mode = true;
            } else if (mem.eql(u8, arg, "--glibc-runtimes")) {
                builder.glibc_runtimes_dir = nextArgOrFatal(args, &arg_idx);
            } else if (mem.eql(u8, arg, "--verbose-link")) {
                builder.verbose_link = true;
            } else if (mem.eql(u8, arg, "--verbose-air")) {
                builder.verbose_air = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                builder.verbose_llvm_ir = "-";
            } else if (mem.startsWith(u8, arg, "--verbose-llvm-ir=")) {
                builder.verbose_llvm_ir = arg["--verbose-llvm-ir=".len..];
            } else if (mem.eql(u8, arg, "--verbose-llvm-bc=")) {
                builder.verbose_llvm_bc = arg["--verbose-llvm-bc=".len..];
            } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                builder.verbose_cimport = true;
            } else if (mem.eql(u8, arg, "--verbose-cc")) {
                builder.verbose_cc = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-cpu-features")) {
                builder.verbose_llvm_cpu_features = true;
            } else if (mem.eql(u8, arg, "--prominent-compile-errors")) {
                prominent_compile_errors = true;
            } else if (mem.eql(u8, arg, "--watch")) {
                watch = true;
            } else if (mem.eql(u8, arg, "--fuzz")) {
                fuzz = true;
            } else if (mem.eql(u8, arg, "-fincremental")) {
                graph.incremental = true;
            } else if (mem.eql(u8, arg, "-fno-incremental")) {
                graph.incremental = false;
            } else if (mem.eql(u8, arg, "-fwine")) {
                builder.enable_wine = true;
            } else if (mem.eql(u8, arg, "-fno-wine")) {
                builder.enable_wine = false;
            } else if (mem.eql(u8, arg, "-fqemu")) {
                builder.enable_qemu = true;
            } else if (mem.eql(u8, arg, "-fno-qemu")) {
                builder.enable_qemu = false;
            } else if (mem.eql(u8, arg, "-fwasmtime")) {
                builder.enable_wasmtime = true;
            } else if (mem.eql(u8, arg, "-fno-wasmtime")) {
                builder.enable_wasmtime = false;
            } else if (mem.eql(u8, arg, "-frosetta")) {
                builder.enable_rosetta = true;
            } else if (mem.eql(u8, arg, "-fno-rosetta")) {
                builder.enable_rosetta = false;
            } else if (mem.eql(u8, arg, "-fdarling")) {
                builder.enable_darling = true;
            } else if (mem.eql(u8, arg, "-fno-darling")) {
                builder.enable_darling = false;
            } else if (mem.eql(u8, arg, "-fallow-so-scripts")) {
                graph.allow_so_scripts = true;
            } else if (mem.eql(u8, arg, "-fno-allow-so-scripts")) {
                graph.allow_so_scripts = false;
            } else if (mem.eql(u8, arg, "-freference-trace")) {
                builder.reference_trace = 256;
            } else if (mem.startsWith(u8, arg, "-freference-trace=")) {
                const num = arg["-freference-trace=".len..];
                builder.reference_trace = std.fmt.parseUnsigned(u32, num, 10) catch |err| {
                    std.debug.print("unable to parse reference_trace count '{s}': {s}", .{ num, @errorName(err) });
                    process.exit(1);
                };
            } else if (mem.eql(u8, arg, "-fno-reference-trace")) {
                builder.reference_trace = null;
            } else if (mem.startsWith(u8, arg, "-j")) {
                const num = arg["-j".len..];
                const n_jobs = std.fmt.parseUnsigned(u32, num, 10) catch |err| {
                    std.debug.print("unable to parse jobs count '{s}': {s}", .{
                        num, @errorName(err),
                    });
                    process.exit(1);
                };
                if (n_jobs < 1) {
                    std.debug.print("number of jobs must be at least 1\n", .{});
                    process.exit(1);
                }
                thread_pool_options.n_jobs = n_jobs;
            } else if (mem.eql(u8, arg, "--")) {
                builder.args = argsRest(args, arg_idx);
                break;
            } else {
                fatalWithHint("unrecognized argument: '{s}'", .{arg});
            }
        } else {
            try targets.append(arg);
        }
    }

    const stderr = std.io.getStdErr();
    const ttyconf = get_tty_conf(color, stderr);
    switch (ttyconf) {
        .no_color => try graph.env_map.put("NO_COLOR", "1"),
        .escape_codes => try graph.env_map.put("CLICOLOR_FORCE", "1"),
        .windows_api => {},
    }

    const main_progress_node = std.Progress.start(.{
        .disable_printing = (color == .off),
    });
    defer main_progress_node.end();

    builder.debug_log_scopes = debug_log_scopes.items;
    builder.resolveInstallPrefix(install_prefix, dir_list);
    {
        var prog_node = main_progress_node.start("Configure", 0);
        defer prog_node.end();
        try builder.runBuild(root);
        createModuleDependencies(builder) catch @panic("OOM");
    }

    if (graph.needed_lazy_dependencies.entries.len != 0) {
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        for (graph.needed_lazy_dependencies.keys()) |k| {
            try buffer.appendSlice(arena, k);
            try buffer.append(arena, '\n');
        }
        const s = std.fs.path.sep_str;
        const tmp_sub_path = "tmp" ++ s ++ (output_tmp_nonce orelse fatal("missing -Z arg", .{}));
        local_cache_directory.handle.writeFile(.{
            .sub_path = tmp_sub_path,
            .data = buffer.items,
            .flags = .{ .exclusive = true },
        }) catch |err| {
            fatal("unable to write configuration results to '{}{s}': {s}", .{
                local_cache_directory, tmp_sub_path, @errorName(err),
            });
        };
        process.exit(3); // Indicate configure phase failed with meaningful stdout.
    }

    if (builder.validateUserInputDidItFail()) {
        fatal("  access the help menu with 'zig build -h'", .{});
    }

    validateSystemLibraryOptions(builder);

    const stdout_writer = io.getStdOut().writer();

    if (help_menu)
        return usage(builder, stdout_writer);

    if (steps_menu)
        return steps(builder, stdout_writer);

    var run: Run = .{
        .max_rss = max_rss,
        .max_rss_is_default = false,
        .max_rss_mutex = .{},
        .skip_oom_steps = skip_oom_steps,
        .watch = watch,
        .fuzz = fuzz,
        .memory_blocked_steps = std.ArrayList(*Step).init(arena),
        .step_stack = .{},
        .prominent_compile_errors = prominent_compile_errors,

        .claimed_rss = 0,
        .summary = summary orelse if (watch) .new else .failures,
        .ttyconf = ttyconf,
        .stderr = stderr,
        .thread_pool = undefined,
    };

    if (run.max_rss == 0) {
        run.max_rss = process.totalSystemMemory() catch std.math.maxInt(u64);
        run.max_rss_is_default = true;
    }

    const gpa = arena;
    prepare(gpa, arena, builder, targets.items, &run, graph.random_seed) catch |err| switch (err) {
        error.UncleanExit => process.exit(1),
        else => return err,
    };

    var w = if (watch) try Watch.init() else undefined;

    try run.thread_pool.init(thread_pool_options);
    defer run.thread_pool.deinit();

    rebuild: while (true) {
        runStepNames(
            gpa,
            builder,
            targets.items,
            main_progress_node,
            &run,
        ) catch |err| switch (err) {
            error.UncleanExit => {
                assert(!run.watch);
                process.exit(1);
            },
            else => return err,
        };
        if (fuzz) {
            switch (builtin.os.tag) {
                // Current implementation depends on two things that need to be ported to Windows:
                // * Memory-mapping to share data between the fuzzer and build runner.
                // * COFF/PE support added to `std.debug.Info` (it needs a batching API for resolving
                //   many addresses to source locations).
                .windows => fatal("--fuzz not yet implemented for {s}", .{@tagName(builtin.os.tag)}),
                else => {},
            }
            const listen_address = std.net.Address.parseIp("127.0.0.1", listen_port) catch unreachable;
            try Fuzz.start(
                gpa,
                arena,
                global_cache_directory,
                zig_lib_directory,
                zig_exe,
                &run.thread_pool,
                run.step_stack.keys(),
                run.ttyconf,
                listen_address,
                main_progress_node,
            );
        }

        if (!watch) return cleanExit();

        if (!Watch.have_impl) fatal("--watch not yet implemented for {s}", .{@tagName(builtin.os.tag)});

        try w.update(gpa, run.step_stack.keys());

        // Wait until a file system notification arrives. Read all such events
        // until the buffer is empty. Then wait for a debounce interval, resetting
        // if any more events come in. After the debounce interval has passed,
        // trigger a rebuild on all steps with modified inputs, as well as their
        // recursive dependants.
        var caption_buf: [std.Progress.Node.max_name_len]u8 = undefined;
        const caption = std.fmt.bufPrint(&caption_buf, "watching {d} directories, {d} processes", .{
            w.dir_table.entries.len, countSubProcesses(run.step_stack.keys()),
        }) catch &caption_buf;
        var debouncing_node = main_progress_node.start(caption, 0);
        var debounce_timeout: Watch.Timeout = .none;
        while (true) switch (try w.wait(gpa, debounce_timeout)) {
            .timeout => {
                debouncing_node.end();
                markFailedStepsDirty(gpa, run.step_stack.keys());
                continue :rebuild;
            },
            .dirty => if (debounce_timeout == .none) {
                debounce_timeout = .{ .ms = debounce_interval_ms };
                debouncing_node.end();
                debouncing_node = main_progress_node.start("Debouncing (Change Detected)", 0);
            },
            .clean => {},
        };
    }
}

fn markFailedStepsDirty(gpa: Allocator, all_steps: []const *Step) void {
    for (all_steps) |step| switch (step.state) {
        .dependency_failure, .failure, .skipped => step.recursiveReset(gpa),
        else => continue,
    };
    // Now that all dirty steps have been found, the remaining steps that
    // succeeded from last run shall be marked "cached".
    for (all_steps) |step| switch (step.state) {
        .success => step.result_cached = true,
        else => continue,
    };
}

fn countSubProcesses(all_steps: []const *Step) usize {
    var count: usize = 0;
    for (all_steps) |s| {
        count += @intFromBool(s.getZigProcess() != null);
    }
    return count;
}

const Run = struct {
    max_rss: u64,
    max_rss_is_default: bool,
    max_rss_mutex: std.Thread.Mutex,
    skip_oom_steps: bool,
    watch: bool,
    fuzz: bool,
    memory_blocked_steps: std.ArrayList(*Step),
    step_stack: std.AutoArrayHashMapUnmanaged(*Step, void),
    prominent_compile_errors: bool,
    thread_pool: std.Thread.Pool,

    claimed_rss: usize,
    summary: Summary,
    ttyconf: std.io.tty.Config,
    stderr: File,

    fn cleanExit(run: Run) void {
        if (run.watch or run.fuzz) return;
        return runner.cleanExit();
    }
};

fn prepare(
    gpa: Allocator,
    arena: Allocator,
    b: *std.Build,
    step_names: []const []const u8,
    run: *Run,
    seed: u32,
) !void {
    const step_stack = &run.step_stack;

    if (step_names.len == 0) {
        try step_stack.put(gpa, b.default_step, {});
    } else {
        try step_stack.ensureUnusedCapacity(gpa, step_names.len);
        for (0..step_names.len) |i| {
            const step_name = step_names[step_names.len - i - 1];
            const s = b.top_level_steps.get(step_name) orelse {
                std.debug.print("no step named '{s}'\n  access the help menu with 'zig build -h'\n", .{step_name});
                process.exit(1);
            };
            step_stack.putAssumeCapacity(&s.step, {});
        }
    }

    const starting_steps = try arena.dupe(*Step, step_stack.keys());

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();
    rand.shuffle(*Step, starting_steps);

    for (starting_steps) |s| {
        constructGraphAndCheckForDependencyLoop(b, s, &run.step_stack, rand) catch |err| switch (err) {
            error.DependencyLoopDetected => return uncleanExit(),
            else => |e| return e,
        };
    }

    {
        // Check that we have enough memory to complete the build.
        var any_problems = false;
        for (step_stack.keys()) |s| {
            if (s.max_rss == 0) continue;
            if (s.max_rss > run.max_rss) {
                if (run.skip_oom_steps) {
                    s.state = .skipped_oom;
                } else {
                    std.debug.print("{s}{s}: this step declares an upper bound of {d} bytes of memory, exceeding the available {d} bytes of memory\n", .{
                        s.owner.dep_prefix, s.name, s.max_rss, run.max_rss,
                    });
                    any_problems = true;
                }
            }
        }
        if (any_problems) {
            if (run.max_rss_is_default) {
                std.debug.print("note: use --maxrss to override the default", .{});
            }
            return uncleanExit();
        }
    }
}

fn runStepNames(
    gpa: Allocator,
    b: *std.Build,
    step_names: []const []const u8,
    parent_prog_node: std.Progress.Node,
    run: *Run,
) !void {
    const step_stack = &run.step_stack;
    const thread_pool = &run.thread_pool;

    {
        const step_prog = parent_prog_node.start("steps", step_stack.count());
        defer step_prog.end();

        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();

        // Here we spawn the initial set of tasks with a nice heuristic -
        // dependency order. Each worker when it finishes a step will then
        // check whether it should run any dependants.
        const steps_slice = step_stack.keys();
        for (0..steps_slice.len) |i| {
            const step = steps_slice[steps_slice.len - i - 1];
            if (step.state == .skipped_oom) continue;

            thread_pool.spawnWg(&wait_group, workerMakeOneStep, .{
                &wait_group, b, step, step_prog, run,
            });
        }
    }
    assert(run.memory_blocked_steps.items.len == 0);

    var test_skip_count: usize = 0;
    var test_fail_count: usize = 0;
    var test_pass_count: usize = 0;
    var test_leak_count: usize = 0;
    var test_count: usize = 0;

    var success_count: usize = 0;
    var skipped_count: usize = 0;
    var failure_count: usize = 0;
    var pending_count: usize = 0;
    var total_compile_errors: usize = 0;

    for (step_stack.keys()) |s| {
        test_fail_count += s.test_results.fail_count;
        test_skip_count += s.test_results.skip_count;
        test_leak_count += s.test_results.leak_count;
        test_pass_count += s.test_results.passCount();
        test_count += s.test_results.test_count;

        switch (s.state) {
            .precheck_unstarted => unreachable,
            .precheck_started => unreachable,
            .running => unreachable,
            .precheck_done => {
                // precheck_done is equivalent to dependency_failure in the case of
                // transitive dependencies. For example:
                // A -> B -> C (failure)
                // B will be marked as dependency_failure, while A may never be queued, and thus
                // remain in the initial state of precheck_done.
                s.state = .dependency_failure;
                pending_count += 1;
            },
            .dependency_failure => pending_count += 1,
            .success => success_count += 1,
            .skipped, .skipped_oom => skipped_count += 1,
            .failure => {
                failure_count += 1;
                const compile_errors_len = s.result_error_bundle.errorMessageCount();
                if (compile_errors_len > 0) {
                    total_compile_errors += compile_errors_len;
                }
            },
        }
    }

    // A proper command line application defaults to silently succeeding.
    // The user may request verbose mode if they have a different preference.
    const failures_only = switch (run.summary) {
        .failures, .none => true,
        else => false,
    };
    if (failure_count == 0 and failures_only) {
        return run.cleanExit();
    }

    const ttyconf = run.ttyconf;

    if (run.summary != .none) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = run.stderr;

        const total_count = success_count + failure_count + pending_count + skipped_count;
        ttyconf.setColor(stderr, .cyan) catch {};
        stderr.writeAll("Build Summary:") catch {};
        ttyconf.setColor(stderr, .reset) catch {};
        stderr.writer().print(" {d}/{d} steps succeeded", .{ success_count, total_count }) catch {};
        if (skipped_count > 0) stderr.writer().print("; {d} skipped", .{skipped_count}) catch {};
        if (failure_count > 0) stderr.writer().print("; {d} failed", .{failure_count}) catch {};

        if (test_count > 0) stderr.writer().print("; {d}/{d} tests passed", .{ test_pass_count, test_count }) catch {};
        if (test_skip_count > 0) stderr.writer().print("; {d} skipped", .{test_skip_count}) catch {};
        if (test_fail_count > 0) stderr.writer().print("; {d} failed", .{test_fail_count}) catch {};
        if (test_leak_count > 0) stderr.writer().print("; {d} leaked", .{test_leak_count}) catch {};

        stderr.writeAll("\n") catch {};

        // Print a fancy tree with build results.
        var step_stack_copy = try step_stack.clone(gpa);
        defer step_stack_copy.deinit(gpa);

        var print_node: PrintNode = .{ .parent = null };
        if (step_names.len == 0) {
            print_node.last = true;
            printTreeStep(b, b.default_step, run, stderr, ttyconf, &print_node, &step_stack_copy) catch {};
        } else {
            const last_index = if (run.summary == .all) b.top_level_steps.count() else blk: {
                var i: usize = step_names.len;
                while (i > 0) {
                    i -= 1;
                    const step = b.top_level_steps.get(step_names[i]).?.step;
                    const found = switch (run.summary) {
                        .all, .none => unreachable,
                        .failures => step.state != .success,
                        .new => !step.result_cached,
                    };
                    if (found) break :blk i;
                }
                break :blk b.top_level_steps.count();
            };
            for (step_names, 0..) |step_name, i| {
                const tls = b.top_level_steps.get(step_name).?;
                print_node.last = i + 1 == last_index;
                printTreeStep(b, &tls.step, run, stderr, ttyconf, &print_node, &step_stack_copy) catch {};
            }
        }
    }

    if (failure_count == 0) {
        return run.cleanExit();
    }

    // Finally, render compile errors at the bottom of the terminal.
    if (run.prominent_compile_errors and total_compile_errors > 0) {
        for (step_stack.keys()) |s| {
            if (s.result_error_bundle.errorMessageCount() > 0) {
                s.result_error_bundle.renderToStdErr(.{ .ttyconf = ttyconf, .include_reference_trace = (b.reference_trace orelse 0) > 0 });
            }
        }

        if (!run.watch) {
            // Signal to parent process that we have printed compile errors. The
            // parent process may choose to omit the "following command failed"
            // line in this case.
            std.debug.lockStdErr();
            process.exit(2);
        }
    }

    if (!run.watch) return uncleanExit();
}

const PrintNode = struct {
    parent: ?*PrintNode,
    last: bool = false,
};

fn printPrefix(node: *PrintNode, stderr: File, ttyconf: std.io.tty.Config) !void {
    const parent = node.parent orelse return;
    if (parent.parent == null) return;
    try printPrefix(parent, stderr, ttyconf);
    if (parent.last) {
        try stderr.writeAll("   ");
    } else {
        try stderr.writeAll(switch (ttyconf) {
            .no_color, .windows_api => "|  ",
            .escape_codes => "\x1B\x28\x30\x78\x1B\x28\x42  ", // │
        });
    }
}

fn printChildNodePrefix(stderr: File, ttyconf: std.io.tty.Config) !void {
    try stderr.writeAll(switch (ttyconf) {
        .no_color, .windows_api => "+- ",
        .escape_codes => "\x1B\x28\x30\x6d\x71\x1B\x28\x42 ", // └─
    });
}

fn printStepStatus(
    s: *Step,
    stderr: File,
    ttyconf: std.io.tty.Config,
    run: *const Run,
) !void {
    switch (s.state) {
        .precheck_unstarted => unreachable,
        .precheck_started => unreachable,
        .precheck_done => unreachable,
        .running => unreachable,

        .dependency_failure => {
            try ttyconf.setColor(stderr, .dim);
            try stderr.writeAll(" transitive failure\n");
            try ttyconf.setColor(stderr, .reset);
        },

        .success => {
            try ttyconf.setColor(stderr, .green);
            if (s.result_cached) {
                try stderr.writeAll(" cached");
            } else if (s.test_results.test_count > 0) {
                const pass_count = s.test_results.passCount();
                try stderr.writer().print(" {d} passed", .{pass_count});
                if (s.test_results.skip_count > 0) {
                    try ttyconf.setColor(stderr, .yellow);
                    try stderr.writer().print(" {d} skipped", .{s.test_results.skip_count});
                }
            } else {
                try stderr.writeAll(" success");
            }
            try ttyconf.setColor(stderr, .reset);
            if (s.result_duration_ns) |ns| {
                try ttyconf.setColor(stderr, .dim);
                if (ns >= std.time.ns_per_min) {
                    try stderr.writer().print(" {d}m", .{ns / std.time.ns_per_min});
                } else if (ns >= std.time.ns_per_s) {
                    try stderr.writer().print(" {d}s", .{ns / std.time.ns_per_s});
                } else if (ns >= std.time.ns_per_ms) {
                    try stderr.writer().print(" {d}ms", .{ns / std.time.ns_per_ms});
                } else if (ns >= std.time.ns_per_us) {
                    try stderr.writer().print(" {d}us", .{ns / std.time.ns_per_us});
                } else {
                    try stderr.writer().print(" {d}ns", .{ns});
                }
                try ttyconf.setColor(stderr, .reset);
            }
            if (s.result_peak_rss != 0) {
                const rss = s.result_peak_rss;
                try ttyconf.setColor(stderr, .dim);
                if (rss >= 1000_000_000) {
                    try stderr.writer().print(" MaxRSS:{d}G", .{rss / 1000_000_000});
                } else if (rss >= 1000_000) {
                    try stderr.writer().print(" MaxRSS:{d}M", .{rss / 1000_000});
                } else if (rss >= 1000) {
                    try stderr.writer().print(" MaxRSS:{d}K", .{rss / 1000});
                } else {
                    try stderr.writer().print(" MaxRSS:{d}B", .{rss});
                }
                try ttyconf.setColor(stderr, .reset);
            }
            try stderr.writeAll("\n");
        },
        .skipped, .skipped_oom => |skip| {
            try ttyconf.setColor(stderr, .yellow);
            try stderr.writeAll(" skipped");
            if (skip == .skipped_oom) {
                try stderr.writeAll(" (not enough memory)");
                try ttyconf.setColor(stderr, .dim);
                try stderr.writer().print(" upper bound of {d} exceeded runner limit ({d})", .{ s.max_rss, run.max_rss });
                try ttyconf.setColor(stderr, .yellow);
            }
            try stderr.writeAll("\n");
            try ttyconf.setColor(stderr, .reset);
        },
        .failure => try printStepFailure(s, stderr, ttyconf),
    }
}

fn printStepFailure(
    s: *Step,
    stderr: File,
    ttyconf: std.io.tty.Config,
) !void {
    if (s.result_error_bundle.errorMessageCount() > 0) {
        try ttyconf.setColor(stderr, .red);
        try stderr.writer().print(" {d} errors\n", .{
            s.result_error_bundle.errorMessageCount(),
        });
        try ttyconf.setColor(stderr, .reset);
    } else if (!s.test_results.isSuccess()) {
        try stderr.writer().print(" {d}/{d} passed", .{
            s.test_results.passCount(), s.test_results.test_count,
        });
        if (s.test_results.fail_count > 0) {
            try stderr.writeAll(", ");
            try ttyconf.setColor(stderr, .red);
            try stderr.writer().print("{d} failed", .{
                s.test_results.fail_count,
            });
            try ttyconf.setColor(stderr, .reset);
        }
        if (s.test_results.skip_count > 0) {
            try stderr.writeAll(", ");
            try ttyconf.setColor(stderr, .yellow);
            try stderr.writer().print("{d} skipped", .{
                s.test_results.skip_count,
            });
            try ttyconf.setColor(stderr, .reset);
        }
        if (s.test_results.leak_count > 0) {
            try stderr.writeAll(", ");
            try ttyconf.setColor(stderr, .red);
            try stderr.writer().print("{d} leaked", .{
                s.test_results.leak_count,
            });
            try ttyconf.setColor(stderr, .reset);
        }
        try stderr.writeAll("\n");
    } else if (s.result_error_msgs.items.len > 0) {
        try ttyconf.setColor(stderr, .red);
        try stderr.writeAll(" failure\n");
        try ttyconf.setColor(stderr, .reset);
    } else {
        assert(s.result_stderr.len > 0);
        try ttyconf.setColor(stderr, .red);
        try stderr.writeAll(" stderr\n");
        try ttyconf.setColor(stderr, .reset);
    }
}

fn printTreeStep(
    b: *std.Build,
    s: *Step,
    run: *const Run,
    stderr: File,
    ttyconf: std.io.tty.Config,
    parent_node: *PrintNode,
    step_stack: *std.AutoArrayHashMapUnmanaged(*Step, void),
) !void {
    const first = step_stack.swapRemove(s);
    const summary = run.summary;
    const skip = switch (summary) {
        .none => unreachable,
        .all => false,
        .new => s.result_cached,
        .failures => s.state == .success,
    };
    if (skip) return;
    try printPrefix(parent_node, stderr, ttyconf);

    if (!first) try ttyconf.setColor(stderr, .dim);
    if (parent_node.parent != null) {
        if (parent_node.last) {
            try printChildNodePrefix(stderr, ttyconf);
        } else {
            try stderr.writeAll(switch (ttyconf) {
                .no_color, .windows_api => "+- ",
                .escape_codes => "\x1B\x28\x30\x74\x71\x1B\x28\x42 ", // ├─
            });
        }
    }

    // dep_prefix omitted here because it is redundant with the tree.
    try stderr.writeAll(s.name);

    if (first) {
        try printStepStatus(s, stderr, ttyconf, run);

        const last_index = if (summary == .all) s.dependencies.items.len -| 1 else blk: {
            var i: usize = s.dependencies.items.len;
            while (i > 0) {
                i -= 1;

                const step = s.dependencies.items[i];
                const found = switch (summary) {
                    .all, .none => unreachable,
                    .failures => step.state != .success,
                    .new => !step.result_cached,
                };
                if (found) break :blk i;
            }
            break :blk s.dependencies.items.len -| 1;
        };
        for (s.dependencies.items, 0..) |dep, i| {
            var print_node: PrintNode = .{
                .parent = parent_node,
                .last = i == last_index,
            };
            try printTreeStep(b, dep, run, stderr, ttyconf, &print_node, step_stack);
        }
    } else {
        if (s.dependencies.items.len == 0) {
            try stderr.writeAll(" (reused)\n");
        } else {
            try stderr.writer().print(" (+{d} more reused dependencies)\n", .{
                s.dependencies.items.len,
            });
        }
        try ttyconf.setColor(stderr, .reset);
    }
}

/// Traverse the dependency graph depth-first and make it undirected by having
/// steps know their dependants (they only know dependencies at start).
/// Along the way, check that there is no dependency loop, and record the steps
/// in traversal order in `step_stack`.
/// Each step has its dependencies traversed in random order, this accomplishes
/// two things:
/// - `step_stack` will be in randomized-depth-first order, so the build runner
///   spawns steps in a random (but optimized) order
/// - each step's `dependants` list is also filled in a random order, so that
///   when it finishes executing in `workerMakeOneStep`, it spawns next steps
///   to run in random order
fn constructGraphAndCheckForDependencyLoop(
    b: *std.Build,
    s: *Step,
    step_stack: *std.AutoArrayHashMapUnmanaged(*Step, void),
    rand: std.Random,
) !void {
    switch (s.state) {
        .precheck_started => {
            std.debug.print("dependency loop detected:\n  {s}\n", .{s.name});
            return error.DependencyLoopDetected;
        },
        .precheck_unstarted => {
            s.state = .precheck_started;

            try step_stack.ensureUnusedCapacity(b.allocator, s.dependencies.items.len);

            // We dupe to avoid shuffling the steps in the summary, it depends
            // on s.dependencies' order.
            const deps = b.allocator.dupe(*Step, s.dependencies.items) catch @panic("OOM");
            rand.shuffle(*Step, deps);

            for (deps) |dep| {
                try step_stack.put(b.allocator, dep, {});
                try dep.dependants.append(b.allocator, s);
                constructGraphAndCheckForDependencyLoop(b, dep, step_stack, rand) catch |err| {
                    if (err == error.DependencyLoopDetected) {
                        std.debug.print("  {s}\n", .{s.name});
                    }
                    return err;
                };
            }

            s.state = .precheck_done;
        },
        .precheck_done => {},

        // These don't happen until we actually run the step graph.
        .dependency_failure => unreachable,
        .running => unreachable,
        .success => unreachable,
        .failure => unreachable,
        .skipped => unreachable,
        .skipped_oom => unreachable,
    }
}

fn workerMakeOneStep(
    wg: *std.Thread.WaitGroup,
    b: *std.Build,
    s: *Step,
    prog_node: std.Progress.Node,
    run: *Run,
) void {
    const thread_pool = &run.thread_pool;

    // First, check the conditions for running this step. If they are not met,
    // then we return without doing the step, relying on another worker to
    // queue this step up again when dependencies are met.
    for (s.dependencies.items) |dep| {
        switch (@atomicLoad(Step.State, &dep.state, .seq_cst)) {
            .success, .skipped => continue,
            .failure, .dependency_failure, .skipped_oom => {
                @atomicStore(Step.State, &s.state, .dependency_failure, .seq_cst);
                return;
            },
            .precheck_done, .running => {
                // dependency is not finished yet.
                return;
            },
            .precheck_unstarted => unreachable,
            .precheck_started => unreachable,
        }
    }

    if (s.max_rss != 0) {
        run.max_rss_mutex.lock();
        defer run.max_rss_mutex.unlock();

        // Avoid running steps twice.
        if (s.state != .precheck_done) {
            // Another worker got the job.
            return;
        }

        const new_claimed_rss = run.claimed_rss + s.max_rss;
        if (new_claimed_rss > run.max_rss) {
            // Running this step right now could possibly exceed the allotted RSS.
            // Add this step to the queue of memory-blocked steps.
            run.memory_blocked_steps.append(s) catch @panic("OOM");
            return;
        }

        run.claimed_rss = new_claimed_rss;
        s.state = .running;
    } else {
        // Avoid running steps twice.
        if (@cmpxchgStrong(Step.State, &s.state, .precheck_done, .running, .seq_cst, .seq_cst) != null) {
            // Another worker got the job.
            return;
        }
    }

    const sub_prog_node = prog_node.start(s.name, 0);
    defer sub_prog_node.end();

    const make_result = s.make(.{
        .progress_node = sub_prog_node,
        .thread_pool = thread_pool,
        .watch = run.watch,
    });

    // No matter the result, we want to display error/warning messages.
    const show_compile_errors = !run.prominent_compile_errors and
        s.result_error_bundle.errorMessageCount() > 0;
    const show_error_msgs = s.result_error_msgs.items.len > 0;
    const show_stderr = s.result_stderr.len > 0;

    if (show_error_msgs or show_compile_errors or show_stderr) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();

        const gpa = b.allocator;
        const options: std.zig.ErrorBundle.RenderOptions = .{
            .ttyconf = run.ttyconf,
            .include_reference_trace = (b.reference_trace orelse 0) > 0,
        };
        printErrorMessages(gpa, s, options, run.stderr, run.prominent_compile_errors) catch {};
    }

    handle_result: {
        if (make_result) |_| {
            @atomicStore(Step.State, &s.state, .success, .seq_cst);
        } else |err| switch (err) {
            error.MakeFailed => {
                @atomicStore(Step.State, &s.state, .failure, .seq_cst);
                break :handle_result;
            },
            error.MakeSkipped => @atomicStore(Step.State, &s.state, .skipped, .seq_cst),
        }

        // Successful completion of a step, so we queue up its dependants as well.
        for (s.dependants.items) |dep| {
            thread_pool.spawnWg(wg, workerMakeOneStep, .{
                wg, b, dep, prog_node, run,
            });
        }
    }

    // If this is a step that claims resources, we must now queue up other
    // steps that are waiting for resources.
    if (s.max_rss != 0) {
        run.max_rss_mutex.lock();
        defer run.max_rss_mutex.unlock();

        // Give the memory back to the scheduler.
        run.claimed_rss -= s.max_rss;
        // Avoid kicking off too many tasks that we already know will not have
        // enough resources.
        var remaining = run.max_rss - run.claimed_rss;
        var i: usize = 0;
        var j: usize = 0;
        while (j < run.memory_blocked_steps.items.len) : (j += 1) {
            const dep = run.memory_blocked_steps.items[j];
            assert(dep.max_rss != 0);
            if (dep.max_rss <= remaining) {
                remaining -= dep.max_rss;

                thread_pool.spawnWg(wg, workerMakeOneStep, .{
                    wg, b, dep, prog_node, run,
                });
            } else {
                run.memory_blocked_steps.items[i] = dep;
                i += 1;
            }
        }
        run.memory_blocked_steps.shrinkRetainingCapacity(i);
    }
}

pub fn printErrorMessages(
    gpa: Allocator,
    failing_step: *Step,
    options: std.zig.ErrorBundle.RenderOptions,
    stderr: File,
    prominent_compile_errors: bool,
) !void {
    // Provide context for where these error messages are coming from by
    // printing the corresponding Step subtree.

    var step_stack: std.ArrayListUnmanaged(*Step) = .empty;
    defer step_stack.deinit(gpa);
    try step_stack.append(gpa, failing_step);
    while (step_stack.items[step_stack.items.len - 1].dependants.items.len != 0) {
        try step_stack.append(gpa, step_stack.items[step_stack.items.len - 1].dependants.items[0]);
    }

    // Now, `step_stack` has the subtree that we want to print, in reverse order.
    const ttyconf = options.ttyconf;
    try ttyconf.setColor(stderr, .dim);
    var indent: usize = 0;
    while (step_stack.pop()) |s| : (indent += 1) {
        if (indent > 0) {
            try stderr.writer().writeByteNTimes(' ', (indent - 1) * 3);
            try printChildNodePrefix(stderr, ttyconf);
        }

        try stderr.writeAll(s.name);

        if (s == failing_step) {
            try printStepFailure(s, stderr, ttyconf);
        } else {
            try stderr.writeAll("\n");
        }
    }
    try ttyconf.setColor(stderr, .reset);

    if (failing_step.result_stderr.len > 0) {
        try stderr.writeAll(failing_step.result_stderr);
        if (!mem.endsWith(u8, failing_step.result_stderr, "\n")) {
            try stderr.writeAll("\n");
        }
    }

    if (!prominent_compile_errors and failing_step.result_error_bundle.errorMessageCount() > 0) {
        try failing_step.result_error_bundle.renderToWriter(options, stderr.writer());
    }

    for (failing_step.result_error_msgs.items) |msg| {
        try ttyconf.setColor(stderr, .red);
        try stderr.writeAll("error: ");
        try ttyconf.setColor(stderr, .reset);
        try stderr.writeAll(msg);
        try stderr.writeAll("\n");
    }
}

fn steps(builder: *std.Build, out_stream: anytype) !void {
    const allocator = builder.allocator;
    for (builder.top_level_steps.values()) |top_level_step| {
        const name = if (&top_level_step.step == builder.default_step)
            try fmt.allocPrint(allocator, "{s} (default)", .{top_level_step.step.name})
        else
            top_level_step.step.name;
        try out_stream.print("  {s:<28} {s}\n", .{ name, top_level_step.description });
    }
}

fn usage(b: *std.Build, out_stream: anytype) !void {
    try out_stream.print(
        \\Usage: {s} build [steps] [options]
        \\
        \\Steps:
        \\
    , .{b.graph.zig_exe});
    try steps(b, out_stream);

    try out_stream.writeAll(
        \\
        \\General Options:
        \\  -p, --prefix [path]          Where to install files (default: zig-out)
        \\  --prefix-lib-dir [path]      Where to install libraries
        \\  --prefix-exe-dir [path]      Where to install executables
        \\  --prefix-include-dir [path]  Where to install C header files
        \\
        \\  --release[=mode]             Request release mode, optionally specifying a
        \\                               preferred optimization mode: fast, safe, small
        \\
        \\  -fdarling,  -fno-darling     Integration with system-installed Darling to
        \\                               execute macOS programs on Linux hosts
        \\                               (default: no)
        \\  -fqemu,     -fno-qemu        Integration with system-installed QEMU to execute
        \\                               foreign-architecture programs on Linux hosts
        \\                               (default: no)
        \\  --glibc-runtimes [path]      Enhances QEMU integration by providing glibc built
        \\                               for multiple foreign architectures, allowing
        \\                               execution of non-native programs that link with glibc.
        \\  -frosetta,  -fno-rosetta     Rely on Rosetta to execute x86_64 programs on
        \\                               ARM64 macOS hosts. (default: no)
        \\  -fwasmtime, -fno-wasmtime    Integration with system-installed wasmtime to
        \\                               execute WASI binaries. (default: no)
        \\  -fwine,     -fno-wine        Integration with system-installed Wine to execute
        \\                               Windows programs on Linux hosts. (default: no)
        \\
        \\  -h, --help                   Print this help and exit
        \\  -l, --list-steps             Print available steps
        \\  --verbose                    Print commands before executing them
        \\  --color [auto|off|on]        Enable or disable colored error messages
        \\  --prominent-compile-errors   Buffer compile errors and display at end
        \\  --summary [mode]             Control the printing of the build summary
        \\    all                        Print the build summary in its entirety
        \\    new                        Omit cached steps
        \\    failures                   (Default) Only print failed steps
        \\    none                       Do not print the build summary
        \\  -j<N>                        Limit concurrent jobs (default is to use all CPU cores)
        \\  --maxrss <bytes>             Limit memory usage (default is to use available memory)
        \\  --skip-oom-steps             Instead of failing, skip steps that would exceed --maxrss
        \\  --fetch                      Exit after fetching dependency tree
        \\  --watch                      Continuously rebuild when source files are modified
        \\  --fuzz                       Continuously search for unit test failures
        \\  --debounce <ms>              Delay before rebuilding after changed file detected
        \\     -fincremental             Enable incremental compilation
        \\  -fno-incremental             Disable incremental compilation
        \\
        \\Project-Specific Options:
        \\
    );

    const arena = b.allocator;
    if (b.available_options_list.items.len == 0) {
        try out_stream.print("  (none)\n", .{});
    } else {
        for (b.available_options_list.items) |option| {
            const name = try fmt.allocPrint(arena, "  -D{s}=[{s}]", .{
                option.name,
                @tagName(option.type_id),
            });
            try out_stream.print("{s:<30} {s}\n", .{ name, option.description });
            if (option.enum_options) |enum_options| {
                const padding = " " ** 33;
                try out_stream.writeAll(padding ++ "Supported Values:\n");
                for (enum_options) |enum_option| {
                    try out_stream.print(padding ++ "  {s}\n", .{enum_option});
                }
            }
        }
    }

    try out_stream.writeAll(
        \\
        \\System Integration Options:
        \\  --search-prefix [path]       Add a path to look for binaries, libraries, headers
        \\  --sysroot [path]             Set the system root directory (usually /)
        \\  --libc [file]                Provide a file which specifies libc paths
        \\
        \\  --system [pkgdir]            Disable package fetching; enable all integrations
        \\  -fsys=[name]                 Enable a system integration
        \\  -fno-sys=[name]              Disable a system integration
        \\
        \\  Available System Integrations:                Enabled:
        \\
    );
    if (b.graph.system_library_options.entries.len == 0) {
        try out_stream.writeAll("  (none)                                        -\n");
    } else {
        for (b.graph.system_library_options.keys(), b.graph.system_library_options.values()) |k, v| {
            const status = switch (v) {
                .declared_enabled => "yes",
                .declared_disabled => "no",
                .user_enabled, .user_disabled => unreachable, // already emitted error
            };
            try out_stream.print("    {s:<43} {s}\n", .{ k, status });
        }
    }

    try out_stream.writeAll(
        \\
        \\Advanced Options:
        \\  -freference-trace[=num]      How many lines of reference trace should be shown per compile error
        \\  -fno-reference-trace         Disable reference trace
        \\  -fallow-so-scripts           Allows .so files to be GNU ld scripts
        \\  -fno-allow-so-scripts        (default) .so files must be ELF files
        \\  --build-file [file]          Override path to build.zig
        \\  --cache-dir [path]           Override path to local Zig cache directory
        \\  --global-cache-dir [path]    Override path to global Zig cache directory
        \\  --zig-lib-dir [arg]          Override path to Zig lib directory
        \\  --build-runner [file]        Override path to build runner
        \\  --seed [integer]             For shuffling dependency traversal order (default: random)
        \\  --debug-log [scope]          Enable debugging the compiler
        \\  --debug-pkg-config           Fail if unknown pkg-config flags encountered
        \\  --debug-rt                   Debug compiler runtime libraries
        \\  --verbose-link               Enable compiler debug output for linking
        \\  --verbose-air                Enable compiler debug output for Zig AIR
        \\  --verbose-llvm-ir[=file]     Enable compiler debug output for LLVM IR
        \\  --verbose-llvm-bc=[file]     Enable compiler debug output for LLVM BC
        \\  --verbose-cimport            Enable compiler debug output for C imports
        \\  --verbose-cc                 Enable compiler debug output for C compilation
        \\  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
        \\
    );
}

fn nextArg(args: []const [:0]const u8, idx: *usize) ?[:0]const u8 {
    if (idx.* >= args.len) return null;
    defer idx.* += 1;
    return args[idx.*];
}

fn nextArgOrFatal(args: []const [:0]const u8, idx: *usize) [:0]const u8 {
    return nextArg(args, idx) orelse {
        std.debug.print("expected argument after '{s}'\n  access the help menu with 'zig build -h'\n", .{args[idx.* - 1]});
        process.exit(1);
    };
}

fn argsRest(args: []const [:0]const u8, idx: usize) ?[]const [:0]const u8 {
    if (idx >= args.len) return null;
    return args[idx..];
}

/// Perhaps in the future there could be an Advanced Options flag such as
/// --debug-build-runner-leaks which would make this function return instead of
/// calling exit.
fn cleanExit() void {
    std.debug.lockStdErr();
    process.exit(0);
}

/// Perhaps in the future there could be an Advanced Options flag such as
/// --debug-build-runner-leaks which would make this function return instead of
/// calling exit.
fn uncleanExit() error{UncleanExit} {
    std.debug.lockStdErr();
    process.exit(1);
}

const Color = std.zig.Color;
const Summary = enum { all, new, failures, none };

fn get_tty_conf(color: Color, stderr: File) std.io.tty.Config {
    return switch (color) {
        .auto => std.io.tty.detectConfig(stderr),
        .on => .escape_codes,
        .off => .no_color,
    };
}

fn fatalWithHint(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print(f ++ "\n  access the help menu with 'zig build -h'\n", args);
    process.exit(1);
}

fn validateSystemLibraryOptions(b: *std.Build) void {
    var bad = false;
    for (b.graph.system_library_options.keys(), b.graph.system_library_options.values()) |k, v| {
        switch (v) {
            .user_disabled, .user_enabled => {
                // The user tried to enable or disable a system library integration, but
                // the build script did not recognize that option.
                std.debug.print("system library name not recognized by build script: '{s}'\n", .{k});
                bad = true;
            },
            .declared_disabled, .declared_enabled => {},
        }
    }
    if (bad) {
        std.debug.print("  access the help menu with 'zig build -h'\n", .{});
        process.exit(1);
    }
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
