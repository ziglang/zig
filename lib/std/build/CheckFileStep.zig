const std = @import("../std.zig");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;
const fs = std.fs;
const mem = std.mem;

const CheckFileStep = @This();

pub const base_id = .check_file;

step: Step,
builder: *Builder,
expected_matches: []const []const u8,
source: build.FileSource,
max_bytes: usize = 20 * 1024 * 1024,

pub fn create(
    builder: *Builder,
    source: build.FileSource,
    expected_matches: []const []const u8,
) *CheckFileStep {
    const self = builder.allocator.create(CheckFileStep) catch unreachable;
    self.* = CheckFileStep{
        .builder = builder,
        .step = Step.init(.check_file, "CheckFile", builder.allocator, make),
        .source = source.dupe(builder),
        .expected_matches = builder.dupeStrings(expected_matches),
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(CheckFileStep, "step", step);

    const src_path = self.source.getPath(self.builder);
    const contents = try fs.cwd().readFileAlloc(self.builder.allocator, src_path, self.max_bytes);

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
