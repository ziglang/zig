const std = @import("../std.zig");
const Step = std.Build.Step;
const FmtStep = @This();

pub const base_id = .fmt;

step: Step,
builder: *std.Build,
argv: [][]const u8,

pub fn create(builder: *std.Build, paths: []const []const u8) *FmtStep {
    const self = builder.allocator.create(FmtStep) catch @panic("OOM");
    const name = "zig fmt";
    self.* = FmtStep{
        .step = Step.init(.fmt, name, builder.allocator, make),
        .builder = builder,
        .argv = builder.allocator.alloc([]u8, paths.len + 2) catch @panic("OOM"),
    };

    self.argv[0] = builder.zig_exe;
    self.argv[1] = "fmt";
    for (paths, 0..) |path, i| {
        self.argv[2 + i] = builder.pathFromRoot(path);
    }
    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(FmtStep, "step", step);

    return self.builder.spawnChild(self.argv);
}
