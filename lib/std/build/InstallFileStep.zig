const std = @import("../std.zig");
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const FileSource = std.build.FileSource;
const InstallDir = std.build.InstallDir;
const InstallFileStep = @This();

pub const base_id = .install_file;

step: Step,
builder: *Builder,
source: FileSource,
dir: InstallDir,
dest_rel_path: []const u8,

pub fn init(
    builder: *Builder,
    source: FileSource,
    dir: InstallDir,
    dest_rel_path: []const u8,
) InstallFileStep {
    builder.pushInstalledFile(dir, dest_rel_path);
    return InstallFileStep{
        .builder = builder,
        .step = Step.init(.install_file, builder.fmt("install {s} to {s}", .{ source.getDisplayName(), dest_rel_path }), builder.allocator, make),
        .source = source.dupe(builder),
        .dir = dir.dupe(builder),
        .dest_rel_path = builder.dupePath(dest_rel_path),
    };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallFileStep, "step", step);
    const full_dest_path = self.builder.getInstallPath(self.dir, self.dest_rel_path);
    const full_src_path = self.source.getPath(self.builder);
    try self.builder.updateFile(full_src_path, full_dest_path);
}
