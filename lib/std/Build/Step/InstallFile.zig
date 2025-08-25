const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const InstallDir = std.Build.InstallDir;
const InstallFile = @This();
const assert = std.debug.assert;

pub const base_id: Step.Id = .install_file;

step: Step,
source: LazyPath,
dir: InstallDir,
dest_rel_path: []const u8,

pub fn create(
    owner: *std.Build,
    source: LazyPath,
    dir: InstallDir,
    dest_rel_path: []const u8,
) *InstallFile {
    assert(dest_rel_path.len != 0);
    const install_file = owner.allocator.create(InstallFile) catch @panic("OOM");
    install_file.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("install {s} to {s}", .{ source.getDisplayName(), dest_rel_path }),
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .dir = dir.dupe(owner),
        .dest_rel_path = owner.dupePath(dest_rel_path),
    };
    source.addStepDependencies(&install_file.step);
    return install_file;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const install_file: *InstallFile = @fieldParentPtr("step", step);
    try step.singleUnchangingWatchInput(install_file.source);

    const full_dest_path = b.getInstallPath(install_file.dir, install_file.dest_rel_path);
    const p = try step.installFile(install_file.source, full_dest_path);
    step.result_cached = p == .fresh;
}
