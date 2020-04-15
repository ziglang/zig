const std = @import("../std.zig");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;

pub const FunctionStep = struct {
    step: Step,
    builder: *Builder,
    function: fn () anyerror!void,

    pub fn create(builder: *Builder, function: fn () anyerror!void) *FunctionStep {
        const self = builder.allocator.create(FunctionStep) catch unreachable;
        self.* = FunctionStep{
            .builder = builder,
            .step = Step.init("Function", builder.allocator, make),
            .function = function,
        };
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(FunctionStep, "step", step);

        try self.function();
    }
};
