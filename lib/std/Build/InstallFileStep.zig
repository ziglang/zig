const std = @import("../std.zig");
const Step = std.Build.Step;
const FileSource = std.Build.FileSource;
const InstallDir = std.Build.InstallDir;
const InstallFileStep = @This();

pub const base_id = .install_file;

step: Step,
source: FileSource,
dir: InstallDir,
dest_rel_path: []const u8,
/// This is used by the build system when a file being installed comes from one
/// package but is being installed by another.
dest_builder: *std.Build,

pub fn init(
    owner: *std.Build,
    source: FileSource,
    dir: InstallDir,
    dest_rel_path: []const u8,
) InstallFileStep {
    owner.pushInstalledFile(dir, dest_rel_path);
    return InstallFileStep{
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
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const src_builder = step.owner;
    const self = @fieldParentPtr(InstallFileStep, "step", step);
    const dest_builder = self.dest_builder;
    const full_src_path = self.source.getPath2(src_builder, step);
    const full_dest_path = dest_builder.getInstallPath(self.dir, self.dest_rel_path);
    try dest_builder.updateFile(full_src_path, full_dest_path);
}
