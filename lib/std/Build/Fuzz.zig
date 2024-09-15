const builtin = @import("builtin");
const std = @import("../std.zig");
const Build = std.Build;
const Step = std.Build.Step;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;
const log = std.log;

const Fuzz = @This();
const build_runner = @import("root");

pub const WebServer = @import("Fuzz/WebServer.zig");
pub const abi = @import("Fuzz/abi.zig");

pub fn start(
    gpa: Allocator,
    arena: Allocator,
    global_cache_directory: Build.Cache.Directory,
    zig_lib_directory: Build.Cache.Directory,
    zig_exe_path: []const u8,
    thread_pool: *std.Thread.Pool,
    all_steps: []const *Step,
    ttyconf: std.io.tty.Config,
    listen_address: std.net.Address,
    prog_node: std.Progress.Node,
) Allocator.Error!void {
    const fuzz_run_steps = block: {
        const rebuild_node = prog_node.start("Rebuilding Unit Tests", 0);
        defer rebuild_node.end();
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();
        var fuzz_run_steps: std.ArrayListUnmanaged(*Step.Run) = .empty;
        defer fuzz_run_steps.deinit(gpa);
        for (all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            if (run.fuzz_tests.items.len > 0 and run.producer != null) {
                thread_pool.spawnWg(&wait_group, rebuildTestsWorkerRun, .{ run, ttyconf, rebuild_node });
                try fuzz_run_steps.append(gpa, run);
            }
        }
        if (fuzz_run_steps.items.len == 0) fatal("no fuzz tests found", .{});
        rebuild_node.setEstimatedTotalItems(fuzz_run_steps.items.len);
        break :block try arena.dupe(*Step.Run, fuzz_run_steps.items);
    };

    // Detect failure.
    for (fuzz_run_steps) |run| {
        assert(run.fuzz_tests.items.len > 0);
        if (run.rebuilt_executable == null)
            fatal("one or more unit tests failed to be rebuilt in fuzz mode", .{});
    }

    var web_server: WebServer = .{
        .gpa = gpa,
        .global_cache_directory = global_cache_directory,
        .zig_lib_directory = zig_lib_directory,
        .zig_exe_path = zig_exe_path,
        .listen_address = listen_address,
        .fuzz_run_steps = fuzz_run_steps,

        .msg_queue = .{},
        .mutex = .{},
        .condition = .{},

        .coverage_files = .{},
        .coverage_mutex = .{},
        .coverage_condition = .{},

        .base_timestamp = std.time.nanoTimestamp(),
    };

    // For accepting HTTP connections.
    const web_server_thread = std.Thread.spawn(.{}, WebServer.run, .{&web_server}) catch |err| {
        fatal("unable to spawn web server thread: {s}", .{@errorName(err)});
    };
    defer web_server_thread.join();

    // For polling messages and sending updates to subscribers.
    const coverage_thread = std.Thread.spawn(.{}, WebServer.coverageRun, .{&web_server}) catch |err| {
        fatal("unable to spawn coverage thread: {s}", .{@errorName(err)});
    };
    defer coverage_thread.join();

    {
        const fuzz_node = prog_node.start("Fuzzing", fuzz_run_steps.len);
        defer fuzz_node.end();
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();

        for (fuzz_run_steps) |run| {
            for (run.fuzz_tests.items) |unit_test_index| {
                assert(run.rebuilt_executable != null);
                thread_pool.spawnWg(&wait_group, fuzzWorkerRun, .{
                    run, &web_server, unit_test_index, ttyconf, fuzz_node,
                });
            }
        }
    }

    log.err("all fuzz workers crashed", .{});
}

fn rebuildTestsWorkerRun(run: *Step.Run, ttyconf: std.io.tty.Config, parent_prog_node: std.Progress.Node) void {
    rebuildTestsWorkerRunFallible(run, ttyconf, parent_prog_node) catch |err| {
        const compile = run.producer.?;
        log.err("step '{s}': failed to rebuild in fuzz mode: {s}", .{
            compile.step.name, @errorName(err),
        });
    };
}

fn rebuildTestsWorkerRunFallible(run: *Step.Run, ttyconf: std.io.tty.Config, parent_prog_node: std.Progress.Node) !void {
    const gpa = run.step.owner.allocator;
    const stderr = std.io.getStdErr();

    const compile = run.producer.?;
    const prog_node = parent_prog_node.start(compile.step.name, 0);
    defer prog_node.end();

    const result = compile.rebuildInFuzzMode(prog_node);

    const show_compile_errors = compile.step.result_error_bundle.errorMessageCount() > 0;
    const show_error_msgs = compile.step.result_error_msgs.items.len > 0;
    const show_stderr = compile.step.result_stderr.len > 0;

    if (show_error_msgs or show_compile_errors or show_stderr) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        build_runner.printErrorMessages(gpa, &compile.step, ttyconf, stderr, false) catch {};
    }

    const rebuilt_bin_path = result catch |err| switch (err) {
        error.MakeFailed => return,
        else => |other| return other,
    };
    run.rebuilt_executable = try rebuilt_bin_path.join(gpa, compile.out_filename);
}

fn fuzzWorkerRun(
    run: *Step.Run,
    web_server: *WebServer,
    unit_test_index: u32,
    ttyconf: std.io.tty.Config,
    parent_prog_node: std.Progress.Node,
) void {
    const gpa = run.step.owner.allocator;
    const test_name = run.cached_test_metadata.?.testName(unit_test_index);

    const prog_node = parent_prog_node.start(test_name, 0);
    defer prog_node.end();

    run.rerunInFuzzMode(web_server, unit_test_index, prog_node) catch |err| switch (err) {
        error.MakeFailed => {
            const stderr = std.io.getStdErr();
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            build_runner.printErrorMessages(gpa, &run.step, ttyconf, stderr, false) catch {};
            return;
        },
        else => {
            log.err("step '{s}': failed to rerun '{s}' in fuzz mode: {s}", .{
                run.step.name, test_name, @errorName(err),
            });
            return;
        },
    };
}
