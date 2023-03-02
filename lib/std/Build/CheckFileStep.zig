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

pub fn create(
    owner: *std.Build,
    source: std.Build.FileSource,
    expected_matches: []const []const u8,
) *CheckFileStep {
    const self = owner.allocator.create(CheckFileStep) catch @panic("OOM");
    self.* = CheckFileStep{
        .step = Step.init(.{
            .id = .check_file,
            .name = "CheckFile",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .expected_matches = owner.dupeStrings(expected_matches),
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const self = @fieldParentPtr(CheckFileStep, "step", step);

    const src_path = self.source.getPath(b);
    const contents = try fs.cwd().readFileAlloc(b.allocator, src_path, self.max_bytes);

    for (self.expected_matches) |expected_match| {
        if (mem.indexOf(u8, contents, expected_match) == null) {
            std.debug.print(
                \\
                \\========= Expected to find: ===================
                \\{s}
                \\========= But file does not contain it: =======
                \\{s}
                \\
            , .{ expected_match, contents });
            return error.TestFailed;
        }
    }
}
