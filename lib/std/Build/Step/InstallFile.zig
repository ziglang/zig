const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const InstallDir = std.Build.InstallDir;
const InstallFile = @This();
const assert = std.debug.assert;

pub const base_id = .install_file;

step: Step,
source: LazyPath,
dir: InstallDir,
dest_rel_path: []const u8,
/// This is used by the build system when a file being installed comes from one
/// package but is being installed by another.
dest_builder: *std.Build,

pub fn create(
    owner: *std.Build,
    source: LazyPath,
    dir: InstallDir,
    dest_rel_path: []const u8,
) *InstallFile {
    assert(dest_rel_path.len != 0);
    owner.pushInstalledFile(dir, dest_rel_path);
    const self = owner.allocator.create(InstallFile) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("install {s} to {s}", .{ source.getDisplayName(), dest_rel_path }),
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .dir = dir.dupe(owner),
        .dest_rel_path = owner.dupePath(dest_rel_path),
        .dest_builder = owner,
    };
    source.addStepDependencies(&self.step);
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const src_builder = step.owner;
    const self = @fieldParentPtr(InstallFile, "step", step);
    const dest_builder = self.dest_builder;
    const full_src_path = self.source.getPath2(src_builder, step);
    const full_dest_path = dest_builder.getInstallPath(self.dir, self.dest_rel_path);
    const cwd = std.fs.cwd();
    const prev = std.fs.Dir.updateFile(cwd, full_src_path, cwd, full_dest_path, .{}) catch |err| {
        return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
            full_src_path, full_dest_path, @errorName(err),
        });
    };
    step.result_cached = prev == .fresh;
}
