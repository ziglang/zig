const std = @import("../std.zig");
const Step = std.Build.Step;
const fs = std.fs;
const mem = std.mem;

const CheckFileStep = @This();

pub const base_id = .check_file;

step: Step,
expected_matches: []const []const u8,
source: std.Build.FileSource,
max_bytes: usize = 20 * 1024 * 1024,

pub const Options = struct {
    expected_matches: []const []const u8,
};

pub fn create(
    owner: *std.Build,
    source: std.Build.FileSource,
    options: Options,
) *CheckFileStep {
    const self = owner.allocator.create(CheckFileStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = .check_file,
            .name = "CheckFile",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .expected_matches = owner.dupeStrings(options.expected_matches),
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

pub fn setName(self: *CheckFileStep, name: []const u8) void {
    self.step.name = name;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const self = @fieldParentPtr(CheckFileStep, "step", step);

    const src_path = self.source.getPath(b);
    const contents = fs.cwd().readFileAlloc(b.allocator, src_path, self.max_bytes) catch |err| {
        return step.fail("unable to read '{s}': {s}", .{
            src_path, @errorName(err),
        });
    };

    for (self.expected_matches) |expected_match| {
        if (mem.indexOf(u8, contents, expected_match) == null) {
            return step.fail(
                \\
                \\========= expected to find: ===================
                \\{s}
                \\========= but file does not contain it: =======
                \\{s}
                \\
            , .{ expected_match, contents });
        }
    }
}
