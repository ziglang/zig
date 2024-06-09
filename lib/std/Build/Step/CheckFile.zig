//! Fail the build step if a file does not match certain checks.
//! TODO: make this more flexible, supporting more kinds of checks.
//! TODO: generalize the code in std.testing.expectEqualStrings and make this
//! CheckFile step produce those helpful diagnostics when there is not a match.
const CheckFile = @This();
const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const mem = std.mem;

step: Step,
expected_matches: []const []const u8,
expected_exact: ?[]const u8,
source: std.Build.LazyPath,
max_bytes: usize = 20 * 1024 * 1024,

pub const base_id: Step.Id = .check_file;

pub const Options = struct {
    expected_matches: []const []const u8 = &.{},
    expected_exact: ?[]const u8 = null,
};

pub fn create(
    owner: *std.Build,
    source: std.Build.LazyPath,
    options: Options,
) *CheckFile {
    const check_file = owner.allocator.create(CheckFile) catch @panic("OOM");
    check_file.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "CheckFile",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .expected_matches = owner.dupeStrings(options.expected_matches),
        .expected_exact = options.expected_exact,
    };
    check_file.source.addStepDependencies(&check_file.step);
    return check_file;
}

pub fn setName(check_file: *CheckFile, name: []const u8) void {
    check_file.step.name = name;
}

fn make(step: *Step, prog_node: std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const check_file: *CheckFile = @fieldParentPtr("step", step);

    const src_path = check_file.source.getPath2(b, step);
    const contents = fs.cwd().readFileAlloc(b.allocator, src_path, check_file.max_bytes) catch |err| {
        return step.fail("unable to read '{s}': {s}", .{
            src_path, @errorName(err),
        });
    };

    for (check_file.expected_matches) |expected_match| {
        if (mem.indexOf(u8, contents, expected_match) == null) {
            return step.fail(
                \\
                \\========= expected to find: ===================
                \\{s}
                \\========= but file does not contain it: =======
                \\{s}
                \\===============================================
            , .{ expected_match, contents });
        }
    }

    if (check_file.expected_exact) |expected_exact| {
        if (!mem.eql(u8, expected_exact, contents)) {
            return step.fail(
                \\
                \\========= expected: =====================
                \\{s}
                \\========= but found: ====================
                \\{s}
                \\========= from the following file: ======
                \\{s}
            , .{ expected_exact, contents, src_path });
        }
    }
}
