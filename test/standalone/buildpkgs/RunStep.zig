const std = @import("std");
const Step = std.build.Step;
const Builder = std.build.Builder;

const RunStep = @This();

pub const Options = struct {
    expect: enum { fail, pass },
    outputs: []const []const u8,
    args: []const []const u8,
    cwd: ?[]const u8 = null,
};

step: Step,
builder: *Builder,
opt: Options,

pub fn init(builder: *Builder, opt: Options) RunStep {
    return .{
        .builder = builder,
        .step = Step.init(.Run, builder.fmt("Run {s} and verify its output", .{opt.args[0]}), builder.allocator, make),
        .opt = opt,
    };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(RunStep, "step", step);
    const child = try std.ChildProcess.init(self.opt.args, std.heap.page_allocator);
    defer child.deinit();
    child.cwd = self.opt.cwd;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stderr = try child.stderr.?.reader().readAllAlloc(self.builder.allocator, std.math.maxInt(usize));
    defer self.builder.allocator.free(stderr);
    errdefer {
        // if we fail, dump the stderr we captured
        std.io.getStdErr().writeAll(stderr) catch @panic("failed to dump stderr in errdefer");
    }
    const passed = switch (try child.wait()) {
        .Exited => |e| e == 0,
        else => false,
    };

    if (passed) {
        if (self.opt.expect == .fail) return error.ZigBuildUnexpectedlyPassed;
    } else {
        if (self.opt.expect == .pass) return error.ZigBuildFailed;
    }
    for (self.opt.outputs) |output| {
        _ = std.mem.indexOf(u8, stderr, output) orelse {
            std.debug.print("Error: did not get expected output '{s}':\n", .{output});
            return error.UnexpectedOutput;
        };
    }
}
