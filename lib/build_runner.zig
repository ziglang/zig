const root = @import("@build");
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

pub const dependencies = @import("@dependencies");

pub fn main() !void {
    // Here we use an ArenaAllocator backed by a DirectAllocator because a build is a short-lived,
    // one shot program. We don't need to waste time freeing memory and finding places to squish
    // bytes into. So we free everything all at once at the very end.
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();

    var thread_safe_arena: std.heap.ThreadSafeAllocator = .{
        .child_allocator = single_threaded_arena.allocator(),
    };
    const arena = thread_safe_arena.allocator();

    var args = try process.argsAlloc(arena);

    // skip my own exe name
    var arg_idx: usize = 1;

    const zig_exe = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected path to zig compiler\n", .{});
        return error.InvalidArgs;
    };
    const build_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected build root directory path\n", .{});
        return error.InvalidArgs;
    };
    const cache_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected cache root directory path\n", .{});
        return error.InvalidArgs;
    };
    const global_cache_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected global cache root directory path\n", .{});
        return error.InvalidArgs;
    };

    const host = try std.zig.system.NativeTargetInfo.detect(.{});

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

    var cache: std.Build.Cache = .{
        .gpa = arena,
        .manifest_dir = try local_cache_directory.handle.makeOpenPath("h", .{}),
    };
    cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
    cache.addPrefix(build_root_directory);
    cache.addPrefix(local_cache_directory);
    cache.addPrefix(global_cache_directory);
    cache.hash.addBytes(builtin.zig_version_string);

    const builder = try std.Build.create(
        arena,
        zig_exe,
        build_root_directory,
        local_cache_directory,
        global_cache_directory,
        host,
        &cache,
    );
    defer builder.destroy();

    var targets = ArrayList([]const u8).init(arena);
    var debug_log_scopes = ArrayList([]const u8).init(arena);
    var thread_pool_options: std.Thread.Pool.Options = .{ .allocator = arena };

    const stderr_stream = io.getStdErr().writer();
    const stdout_stream = io.getStdOut().writer();

    var install_prefix: ?[]const u8 = null;
    var dir_list = std.Build.DirList{};
    var enable_summary: ?bool = null;

    const Color = enum { auto, off, on };
    var color: Color = .auto;

    while (nextArg(args, &arg_idx)) |arg| {
        if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2..];
            if (option_contents.len == 0) {
                std.debug.print("Expected option name after '-D'\n\n", .{});
                usageAndErr(builder, false, stderr_stream);
            }
            if (mem.indexOfScalar(u8, option_contents, '=')) |name_end| {
                const option_name = option_contents[0..name_end];
                const option_value = option_contents[name_end + 1 ..];
                if (try builder.addUserInputOption(option_name, option_value))
                    usageAndErr(builder, false, stderr_stream);
            } else {
                if (try builder.addUserInputFlag(option_contents))
                    usageAndErr(builder, false, stderr_stream);
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                return usage(builder, false, stdout_stream);
            } else if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--prefix")) {
                install_prefix = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--list-steps")) {
                return steps(builder, false, stdout_stream);
            } else if (mem.eql(u8, arg, "--prefix-lib-dir")) {
                dir_list.lib_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--prefix-exe-dir")) {
                dir_list.exe_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--prefix-include-dir")) {
                dir_list.include_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--sysroot")) {
                const sysroot = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --sysroot\n\n", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
                builder.sysroot = sysroot;
            } else if (mem.eql(u8, arg, "--search-prefix")) {
                const search_prefix = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --search-prefix\n\n", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
                builder.addSearchPrefix(search_prefix);
            } else if (mem.eql(u8, arg, "--libc")) {
                const libc_file = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --libc\n\n", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
                builder.libc_file = libc_file;
            } else if (mem.eql(u8, arg, "--color")) {
                const next_arg = nextArg(args, &arg_idx) orelse {
                    std.debug.print("expected [auto|on|off] after --color", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
                color = std.meta.stringToEnum(Color, next_arg) orelse {
                    std.debug.print("expected [auto|on|off] after --color, found '{s}'", .{next_arg});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                builder.zig_lib_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --zig-lib-dir\n\n", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--debug-log")) {
                const next_arg = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    usageAndErr(builder, false, stderr_stream);
                };
                try debug_log_scopes.append(next_arg);
            } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                builder.debug_compile_errors = true;
            } else if (mem.eql(u8, arg, "--glibc-runtimes")) {
                builder.glibc_runtimes_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --glibc-runtimes\n\n", .{});
                    usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--verbose-link")) {
                builder.verbose_link = true;
            } else if (mem.eql(u8, arg, "--verbose-air")) {
                builder.verbose_air = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                builder.verbose_llvm_ir = true;
            } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                builder.verbose_cimport = true;
            } else if (mem.eql(u8, arg, "--verbose-cc")) {
                builder.verbose_cc = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-cpu-features")) {
                builder.verbose_llvm_cpu_features = true;
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
            } else if (mem.eql(u8, arg, "-fsummary")) {
                enable_summary = true;
            } else if (mem.eql(u8, arg, "-fno-summary")) {
                enable_summary = false;
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
                std.debug.print("Unrecognized argument: {s}\n\n", .{arg});
                usageAndErr(builder, false, stderr_stream);
            }
        } else {
            try targets.append(arg);
        }
    }

    const stderr = std.io.getStdErr();
    const ttyconf: std.debug.TTY.Config = switch (color) {
        .auto => std.debug.detectTTYConfig(stderr),
        .on => .escape_codes,
        .off => .no_color,
    };

    var progress: std.Progress = .{};
    const main_progress_node = progress.start("", 0);

    builder.debug_log_scopes = debug_log_scopes.items;
    builder.resolveInstallPrefix(install_prefix, dir_list);
    {
        var prog_node = main_progress_node.start("user build.zig logic", 0);
        defer prog_node.end();
        try builder.runBuild(root);
    }

    if (builder.validateUserInputDidItFail())
        usageAndErr(builder, true, stderr_stream);

    runStepNames(
        arena,
        builder,
        targets.items,
        main_progress_node,
        thread_pool_options,
        ttyconf,
        stderr,
        enable_summary,
    ) catch |err| switch (err) {
        error.UncleanExit => process.exit(1),
        else => return err,
    };
}

fn runStepNames(
    arena: std.mem.Allocator,
    b: *std.Build,
    step_names: []const []const u8,
    parent_prog_node: *std.Progress.Node,
    thread_pool_options: std.Thread.Pool.Options,
    ttyconf: std.debug.TTY.Config,
    stderr: std.fs.File,
    enable_summary: ?bool,
) !void {
    const gpa = b.allocator;
    var step_stack: std.AutoArrayHashMapUnmanaged(*Step, void) = .{};
    defer step_stack.deinit(gpa);

    if (step_names.len == 0) {
        try step_stack.put(gpa, b.default_step, {});
    } else {
        try step_stack.ensureUnusedCapacity(gpa, step_names.len);
        for (0..step_names.len) |i| {
            const step_name = step_names[step_names.len - i - 1];
            const s = b.top_level_steps.get(step_name) orelse {
                std.debug.print("no step named '{s}'. Access the help menu with 'zig build -h'\n", .{step_name});
                process.exit(1);
            };
            step_stack.putAssumeCapacity(&s.step, {});
        }
    }

    const starting_steps = try arena.dupe(*Step, step_stack.keys());
    for (starting_steps) |s| {
        checkForDependencyLoop(b, s, &step_stack) catch |err| switch (err) {
            error.DependencyLoopDetected => return error.UncleanExit,
            else => |e| return e,
        };
    }

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(thread_pool_options);
    defer thread_pool.deinit();

    {
        defer parent_prog_node.end();

        var step_prog = parent_prog_node.start("run steps", step_stack.count());
        defer step_prog.end();

        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();

        // Here we spawn the initial set of tasks with a nice heuristic -
        // dependency order. Each worker when it finishes a step will then
        // check whether it should run any dependants.
        const steps_slice = step_stack.keys();
        for (0..steps_slice.len) |i| {
            const step = steps_slice[steps_slice.len - i - 1];

            wait_group.start();
            thread_pool.spawn(workerMakeOneStep, .{
                &wait_group, &thread_pool, b, step, &step_prog, ttyconf,
            }) catch @panic("OOM");
        }
    }

    var success_count: usize = 0;
    var skipped_count: usize = 0;
    var failure_count: usize = 0;
    var pending_count: usize = 0;
    var total_compile_errors: usize = 0;
    var compile_error_steps: std.ArrayListUnmanaged(*Step) = .{};
    defer compile_error_steps.deinit(gpa);

    for (step_stack.keys()) |s| {
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
            .skipped => skipped_count += 1,
            .failure => {
                failure_count += 1;
                const compile_errors_len = s.result_error_bundle.errorMessageCount();
                if (compile_errors_len > 0) {
                    total_compile_errors += compile_errors_len;
                    try compile_error_steps.append(gpa, s);
                }
            },
        }
    }

    // A proper command line application defaults to silently succeeding.
    // The user may request verbose mode if they have a different preference.
    if (failure_count == 0 and enable_summary != true) return cleanExit();

    if (enable_summary != false) {
        const total_count = success_count + failure_count + pending_count + skipped_count;
        ttyconf.setColor(stderr, .Cyan) catch {};
        stderr.writeAll("Build Summary:") catch {};
        ttyconf.setColor(stderr, .Reset) catch {};
        stderr.writer().print(" {d}/{d} steps succeeded", .{ success_count, total_count }) catch {};
        if (skipped_count > 0) stderr.writer().print("; {d} skipped", .{skipped_count}) catch {};
        if (failure_count > 0) stderr.writer().print("; {d} failed", .{failure_count}) catch {};

        if (enable_summary == null) {
            ttyconf.setColor(stderr, .Dim) catch {};
            stderr.writeAll(" (disable with -fno-summary)") catch {};
            ttyconf.setColor(stderr, .Reset) catch {};
        }
        stderr.writeAll("\n") catch {};

        // Print a fancy tree with build results.
        var print_node: PrintNode = .{ .parent = null };
        if (step_names.len == 0) {
            print_node.last = true;
            printTreeStep(b, b.default_step, stderr, ttyconf, &print_node, &step_stack) catch {};
        } else {
            for (step_names, 0..) |step_name, i| {
                const tls = b.top_level_steps.get(step_name).?;
                print_node.last = i + 1 == b.top_level_steps.count();
                printTreeStep(b, &tls.step, stderr, ttyconf, &print_node, &step_stack) catch {};
            }
        }
    }

    if (failure_count == 0) return cleanExit();

    // Finally, render compile errors at the bottom of the terminal.
    // We use a separate compile_error_steps array list because step_stack is destructively
    // mutated in printTreeStep above.
    if (total_compile_errors > 0) {
        for (compile_error_steps.items) |s| {
            if (s.result_error_bundle.errorMessageCount() > 0) {
                s.result_error_bundle.renderToStdErr(ttyconf);
            }
        }

        // Signal to parent process that we have printed compile errors. The
        // parent process may choose to omit the "following command failed"
        // line in this case.
        process.exit(2);
    }

    process.exit(1);
}

const PrintNode = struct {
    parent: ?*PrintNode,
    last: bool = false,
};

fn printPrefix(node: *PrintNode, stderr: std.fs.File) !void {
    const parent = node.parent orelse return;
    if (parent.parent == null) return;
    try printPrefix(parent, stderr);
    if (parent.last) {
        try stderr.writeAll("   ");
    } else {
        try stderr.writeAll("│  ");
    }
}

fn printTreeStep(
    b: *std.Build,
    s: *Step,
    stderr: std.fs.File,
    ttyconf: std.debug.TTY.Config,
    parent_node: *PrintNode,
    step_stack: *std.AutoArrayHashMapUnmanaged(*Step, void),
) !void {
    const first = step_stack.swapRemove(s);
    try printPrefix(parent_node, stderr);

    if (!first) try ttyconf.setColor(stderr, .Dim);
    if (parent_node.parent != null) {
        if (parent_node.last) {
            try stderr.writeAll("└─ ");
        } else {
            try stderr.writeAll("├─ ");
        }
    }

    // dep_prefix omitted here because it is redundant with the tree.
    try stderr.writeAll(s.name);

    if (first) {
        switch (s.state) {
            .precheck_unstarted => unreachable,
            .precheck_started => unreachable,
            .precheck_done => unreachable,
            .running => unreachable,

            .dependency_failure => {
                try ttyconf.setColor(stderr, .Dim);
                try stderr.writeAll(" transitive failure\n");
                try ttyconf.setColor(stderr, .Reset);
            },

            .success => {
                try ttyconf.setColor(stderr, .Green);
                try stderr.writeAll(" success\n");
                try ttyconf.setColor(stderr, .Reset);
            },

            .skipped => {
                try ttyconf.setColor(stderr, .Yellow);
                try stderr.writeAll(" skipped\n");
                try ttyconf.setColor(stderr, .Reset);
            },

            .failure => {
                try ttyconf.setColor(stderr, .Red);
                if (s.result_error_bundle.errorMessageCount() > 0) {
                    try stderr.writer().print(" {d} errors\n", .{
                        s.result_error_bundle.errorMessageCount(),
                    });
                } else {
                    try stderr.writeAll(" failure\n");
                }
                try ttyconf.setColor(stderr, .Reset);
            },
        }

        for (s.dependencies.items, 0..) |dep, i| {
            var print_node: PrintNode = .{
                .parent = parent_node,
                .last = i == s.dependencies.items.len - 1,
            };
            try printTreeStep(b, dep, stderr, ttyconf, &print_node, step_stack);
        }
    } else {
        if (s.dependencies.items.len == 0) {
            try stderr.writeAll(" (reused)\n");
        } else {
            try stderr.writer().print(" (+{d} more reused dependencies)\n", .{
                s.dependencies.items.len,
            });
        }
        try ttyconf.setColor(stderr, .Reset);
    }
}

fn checkForDependencyLoop(
    b: *std.Build,
    s: *Step,
    step_stack: *std.AutoArrayHashMapUnmanaged(*Step, void),
) !void {
    switch (s.state) {
        .precheck_started => {
            std.debug.print("dependency loop detected:\n  {s}\n", .{s.name});
            return error.DependencyLoopDetected;
        },
        .precheck_unstarted => {
            s.state = .precheck_started;

            try step_stack.ensureUnusedCapacity(b.allocator, s.dependencies.items.len);
            for (s.dependencies.items) |dep| {
                try step_stack.put(b.allocator, dep, {});
                try dep.dependants.append(b.allocator, s);
                checkForDependencyLoop(b, dep, step_stack) catch |err| {
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
    }
}

fn workerMakeOneStep(
    wg: *std.Thread.WaitGroup,
    thread_pool: *std.Thread.Pool,
    b: *std.Build,
    s: *Step,
    prog_node: *std.Progress.Node,
    ttyconf: std.debug.TTY.Config,
) void {
    defer wg.finish();

    // First, check the conditions for running this step. If they are not met,
    // then we return without doing the step, relying on another worker to
    // queue this step up again when dependencies are met.
    for (s.dependencies.items) |dep| {
        switch (@atomicLoad(Step.State, &dep.state, .SeqCst)) {
            .success, .skipped => continue,
            .failure, .dependency_failure => {
                @atomicStore(Step.State, &s.state, .dependency_failure, .SeqCst);
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

    // Avoid running steps twice.
    if (@cmpxchgStrong(Step.State, &s.state, .precheck_done, .running, .SeqCst, .SeqCst) != null) {
        // Another worker got the job.
        return;
    }

    var sub_prog_node = prog_node.start(s.name, 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    // I suspect we will want to pass `b` to make() in a future modification.
    // For example, CompileStep does some sus things with modifying the saved
    // *Build object in install header steps that might be able to be removed
    // by passing the *Build object through the make() functions.
    const make_result = s.make(&sub_prog_node);

    // No matter the result, we want to display error/warning messages.
    if (s.result_error_msgs.items.len > 0) {
        sub_prog_node.context.lock_stderr();
        defer sub_prog_node.context.unlock_stderr();

        const stderr = std.io.getStdErr();

        for (s.result_error_msgs.items) |msg| {
            // Sometimes it feels like you just can't catch a break. Finally,
            // with Zig, you can.
            ttyconf.setColor(stderr, .Bold) catch break;
            stderr.writeAll(s.owner.dep_prefix) catch break;
            stderr.writeAll(s.name) catch break;
            stderr.writeAll(": ") catch break;
            ttyconf.setColor(stderr, .Red) catch break;
            stderr.writeAll("error: ") catch break;
            ttyconf.setColor(stderr, .Reset) catch break;
            stderr.writeAll(msg) catch break;
            stderr.writeAll("\n") catch break;
        }
    }

    if (make_result) |_| {
        @atomicStore(Step.State, &s.state, .success, .SeqCst);
    } else |err| switch (err) {
        error.MakeFailed => {
            @atomicStore(Step.State, &s.state, .failure, .SeqCst);
            return;
        },
        error.MakeSkipped => @atomicStore(Step.State, &s.state, .skipped, .SeqCst),
    }

    // Successful completion of a step, so we queue up its dependants as well.
    for (s.dependants.items) |dep| {
        wg.start();
        thread_pool.spawn(workerMakeOneStep, .{
            wg, thread_pool, b, dep, prog_node, ttyconf,
        }) catch @panic("OOM");
    }
}

fn steps(builder: *std.Build, already_ran_build: bool, out_stream: anytype) !void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.resolveInstallPrefix(null, .{});
        try builder.runBuild(root);
    }

    const allocator = builder.allocator;
    for (builder.top_level_steps.values()) |top_level_step| {
        const name = if (&top_level_step.step == builder.default_step)
            try fmt.allocPrint(allocator, "{s} (default)", .{top_level_step.step.name})
        else
            top_level_step.step.name;
        try out_stream.print("  {s:<28} {s}\n", .{ name, top_level_step.description });
    }
}

fn usage(builder: *std.Build, already_ran_build: bool, out_stream: anytype) !void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.resolveInstallPrefix(null, .{});
        try builder.runBuild(root);
    }

    try out_stream.print(
        \\
        \\Usage: {s} build [steps] [options]
        \\
        \\Steps:
        \\
    , .{builder.zig_exe});
    try steps(builder, true, out_stream);

    try out_stream.writeAll(
        \\
        \\General Options:
        \\  -p, --prefix [path]          Override default install prefix
        \\  --prefix-lib-dir [path]      Override default library directory path
        \\  --prefix-exe-dir [path]      Override default executable directory path
        \\  --prefix-include-dir [path]  Override default include directory path
        \\
        \\  --sysroot [path]             Set the system root directory (usually /)
        \\  --search-prefix [path]       Add a path to look for binaries, libraries, headers
        \\  --libc [file]                Provide a file which specifies libc paths
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
        \\  --prominent-compile-errors   Output compile errors formatted for a human to read
        \\  -j<N>                        Limit concurrent jobs (default is to use all CPU cores)
        \\
        \\Project-Specific Options:
        \\
    );

    const allocator = builder.allocator;
    if (builder.available_options_list.items.len == 0) {
        try out_stream.print("  (none)\n", .{});
    } else {
        for (builder.available_options_list.items) |option| {
            const name = try fmt.allocPrint(allocator, "  -D{s}=[{s}]", .{
                option.name,
                @tagName(option.type_id),
            });
            defer allocator.free(name);
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
        \\Advanced Options:
        \\  -freference-trace[=num]      How many lines of reference trace should be shown per compile error
        \\  -fno-reference-trace         Disable reference trace
        \\  -fsummary                    Print the build summary, even on success
        \\  -fno-summary                 Omit the build summary, even on failure
        \\  --build-file [file]          Override path to build.zig
        \\  --cache-dir [path]           Override path to local Zig cache directory
        \\  --global-cache-dir [path]    Override path to global Zig cache directory
        \\  --zig-lib-dir [arg]          Override path to Zig lib directory
        \\  --build-runner [file]        Override path to build runner
        \\  --debug-log [scope]          Enable debugging the compiler
        \\  --verbose-link               Enable compiler debug output for linking
        \\  --verbose-air                Enable compiler debug output for Zig AIR
        \\  --verbose-llvm-ir            Enable compiler debug output for LLVM IR
        \\  --verbose-cimport            Enable compiler debug output for C imports
        \\  --verbose-cc                 Enable compiler debug output for C compilation
        \\  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
        \\
    );
}

fn usageAndErr(builder: *std.Build, already_ran_build: bool, out_stream: anytype) noreturn {
    usage(builder, already_ran_build, out_stream) catch {};
    process.exit(1);
}

fn nextArg(args: [][]const u8, idx: *usize) ?[]const u8 {
    if (idx.* >= args.len) return null;
    defer idx.* += 1;
    return args[idx.*];
}

fn argsRest(args: [][]const u8, idx: usize) ?[][]const u8 {
    if (idx >= args.len) return null;
    return args[idx..];
}

fn cleanExit() void {
    // Perhaps in the future there could be an Advanced Options flag such as
    // --debug-build-runner-leaks which would make this function return instead
    // of calling exit.
    process.exit(0);
}
