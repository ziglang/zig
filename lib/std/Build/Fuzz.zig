const std = @import("../std.zig");
const Fuzz = @This();
const Step = std.Build.Step;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const build_runner = @import("root");

pub fn start(
    thread_pool: *std.Thread.Pool,
    all_steps: []const *Step,
    ttyconf: std.io.tty.Config,
    prog_node: std.Progress.Node,
) void {
    const count = block: {
        const rebuild_node = prog_node.start("Rebuilding Unit Tests", 0);
        defer rebuild_node.end();
        var count: usize = 0;
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();
        for (all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            if (run.fuzz_tests.items.len > 0 and run.producer != null) {
                thread_pool.spawnWg(&wait_group, rebuildTestsWorkerRun, .{ run, ttyconf, rebuild_node });
                count += 1;
            }
        }
        if (count == 0) fatal("no fuzz tests found", .{});
        rebuild_node.setEstimatedTotalItems(count);
        break :block count;
    };

    // Detect failure.
    for (all_steps) |step| {
        const run = step.cast(Step.Run) orelse continue;
        if (run.fuzz_tests.items.len > 0 and run.rebuilt_executable == null)
            fatal("one or more unit tests failed to be rebuilt in fuzz mode", .{});
    }

    {
        const fuzz_node = prog_node.start("Fuzzing", count);
        defer fuzz_node.end();
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();

        for (all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            for (run.fuzz_tests.items) |unit_test_index| {
                assert(run.rebuilt_executable != null);
                thread_pool.spawnWg(&wait_group, fuzzWorkerRun, .{ run, unit_test_index, ttyconf, fuzz_node });
            }
        }
    }

    fatal("all fuzz workers crashed", .{});
}

fn rebuildTestsWorkerRun(run: *Step.Run, ttyconf: std.io.tty.Config, parent_prog_node: std.Progress.Node) void {
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

    if (result) |rebuilt_bin_path| {
        run.rebuilt_executable = rebuilt_bin_path;
    } else |err| switch (err) {
        error.MakeFailed => {},
        else => {
            std.debug.print("step '{s}': failed to rebuild in fuzz mode: {s}\n", .{
                compile.step.name, @errorName(err),
            });
        },
    }
}

fn fuzzWorkerRun(
    run: *Step.Run,
    unit_test_index: u32,
    ttyconf: std.io.tty.Config,
    parent_prog_node: std.Progress.Node,
) void {
    const gpa = run.step.owner.allocator;
    const test_name = run.cached_test_metadata.?.testName(unit_test_index);

    const prog_node = parent_prog_node.start(test_name, 0);
    defer prog_node.end();

    run.rerunInFuzzMode(unit_test_index, prog_node) catch |err| switch (err) {
        error.MakeFailed => {
            const stderr = std.io.getStdErr();
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            build_runner.printErrorMessages(gpa, &run.step, ttyconf, stderr, false) catch {};
        },
        else => {
            std.debug.print("step '{s}': failed to rebuild '{s}' in fuzz mode: {s}\n", .{
                run.step.name, test_name, @errorName(err),
            });
        },
    };
}
