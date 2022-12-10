const std = @import("../std.zig");
const log = std.log;
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const LogStep = @This();

pub const base_id = .log;

step: Step,
builder: *Builder,
data: []const u8,

pub fn init(builder: *Builder, data: []const u8) LogStep {
    return LogStep{
        .builder = builder,
        .step = Step.init(.log, builder.fmt("log {s}", .{data}), builder.allocator, make),
        .data = builder.dupe(data),
    };
}

fn make(step: *Step) anyerror!void {
    const self = @fieldParentPtr(LogStep, "step", step);
    log.info("{s}", .{self.data});
}
