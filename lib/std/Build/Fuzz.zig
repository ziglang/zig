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
    const compile_step = run.producer.?;
    const prog_node = parent_prog_node.start(compile_step.step.name, 0);
    defer prog_node.end();
    if (compile_step.rebuildInFuzzMode(prog_node)) |rebuilt_bin_path| {
        run.rebuilt_executable = rebuilt_bin_path;
    } else |err| switch (err) {
        error.MakeFailed => {
            const b = run.step.owner;
            const stderr = std.io.getStdErr();
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            build_runner.printErrorMessages(b, &compile_step.step, ttyconf, stderr, false) catch {};
        },
        else => {
            std.debug.print("step '{s}': failed to rebuild in fuzz mode: {s}\n", .{
                compile_step.step.name, @errorName(err),
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
    const test_name = run.cached_test_metadata.?.testName(unit_test_index);

    const prog_node = parent_prog_node.start(test_name, 0);
    defer prog_node.end();

    run.rerunInFuzzMode(unit_test_index, prog_node) catch |err| switch (err) {
        error.MakeFailed => {
            const b = run.step.owner;
            const stderr = std.io.getStdErr();
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            build_runner.printErrorMessages(b, &run.step, ttyconf, stderr, false) catch {};
        },
        else => {
            std.debug.print("step '{s}': failed to rebuild '{s}' in fuzz mode: {s}\n", .{
                run.step.name, test_name, @errorName(err),
            });
        },
    };
}
