const std = @import("../std.zig");
const Fuzz = @This();
const Step = std.Build.Step;
const assert = std.debug.assert;
const fatal = std.process.fatal;

pub fn start(thread_pool: *std.Thread.Pool, all_steps: []const *Step, prog_node: std.Progress.Node) void {
    {
        const rebuild_node = prog_node.start("Rebuilding Unit Tests", 0);
        defer rebuild_node.end();
        var count: usize = 0;
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();
        for (all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            if (run.fuzz_tests.items.len > 0 and run.producer != null) {
                thread_pool.spawnWg(&wait_group, rebuildTestsWorkerRun, .{ run, prog_node });
                count += 1;
            }
        }
        if (count == 0) fatal("no fuzz tests found", .{});
        rebuild_node.setEstimatedTotalItems(count);
    }

    // Detect failure.
    for (all_steps) |step| {
        const run = step.cast(Step.Run) orelse continue;
        if (run.fuzz_tests.items.len > 0 and run.rebuilt_executable == null)
            fatal("one or more unit tests failed to be rebuilt in fuzz mode", .{});
    }

    @panic("TODO do something with the rebuilt unit tests");
}

fn rebuildTestsWorkerRun(run: *Step.Run, parent_prog_node: std.Progress.Node) void {
    const compile_step = run.producer.?;
    const prog_node = parent_prog_node.start(compile_step.step.name, 0);
    defer prog_node.end();
    const rebuilt_bin_path = compile_step.rebuildInFuzzMode(prog_node) catch |err| {
        std.debug.print("failed to rebuild {s} in fuzz mode: {s}", .{
            compile_step.step.name, @errorName(err),
        });
        return;
    };
    run.rebuilt_executable = rebuilt_bin_path;
}
