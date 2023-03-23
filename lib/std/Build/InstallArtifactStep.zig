const std = @import("../std.zig");
const Step = std.Build.Step;
const CompileStep = std.Build.CompileStep;
const InstallDir = std.Build.InstallDir;
const InstallArtifactStep = @This();
const fs = std.fs;

pub const base_id = .install_artifact;

step: Step,
dest_builder: *std.Build,
artifact: *CompileStep,
dest_dir: InstallDir,
pdb_dir: ?InstallDir,
h_dir: ?InstallDir,
/// If non-null, adds additional path components relative to dest_dir, and
/// overrides the basename of the CompileStep.
dest_sub_path: ?[]const u8,

pub fn create(owner: *std.Build, artifact: *CompileStep) *InstallArtifactStep {
    if (artifact.install_step) |s| return s;

    const self = owner.allocator.create(InstallArtifactStep) catch @panic("OOM");
    self.* = InstallArtifactStep{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("install {s}", .{artifact.name}),
            .owner = owner,
            .makeFn = make,
        }),
        .dest_builder = owner,
        .artifact = artifact,
        .dest_dir = artifact.override_dest_dir orelse switch (artifact.kind) {
            .obj => @panic("Cannot install a .obj build artifact."),
            .exe, .@"test" => InstallDir{ .bin = {} },
            .lib => InstallDir{ .lib = {} },
        },
        .pdb_dir = if (artifact.producesPdbFile()) blk: {
            if (artifact.kind == .exe or artifact.kind == .@"test") {
                break :blk InstallDir{ .bin = {} };
            } else {
                break :blk InstallDir{ .lib = {} };
            }
        } else null,
        .h_dir = if (artifact.kind == .lib and artifact.emit_h) .header else null,
        .dest_sub_path = null,
    };
    self.step.dependOn(&artifact.step);
    artifact.install_step = self;

    owner.pushInstalledFile(self.dest_dir, artifact.out_filename);
    if (self.artifact.isDynamicLibrary()) {
        if (artifact.major_only_filename) |name| {
            owner.pushInstalledFile(.lib, name);
        }
        if (artifact.name_only_filename) |name| {
            owner.pushInstalledFile(.lib, name);
        }
        if (self.artifact.target.isWindows()) {
            owner.pushInstalledFile(.lib, artifact.out_lib_filename);
        }
    }
    if (self.pdb_dir) |pdb_dir| {
        owner.pushInstalledFile(pdb_dir, artifact.out_pdb_filename);
    }
    if (self.h_dir) |h_dir| {
        owner.pushInstalledFile(h_dir, artifact.out_h_filename);
    }
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const src_builder = step.owner;
    const self = @fieldParentPtr(InstallArtifactStep, "step", step);
    const dest_builder = self.dest_builder;

    const dest_sub_path = if (self.dest_sub_path) |sub_path| sub_path else self.artifact.out_filename;
    const full_dest_path = dest_builder.getInstallPath(self.dest_dir, dest_sub_path);
    const cwd = fs.cwd();

    var all_cached = true;

    {
        const full_src_path = self.artifact.getOutputSource().getPath(src_builder);
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_dest_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_dest_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }

    if (self.artifact.isDynamicLibrary() and
        self.artifact.version != null and
        self.artifact.target.wantSharedLibSymLinks())
    {
        try CompileStep.doAtomicSymLinks(step, full_dest_path, self.artifact.major_only_filename.?, self.artifact.name_only_filename.?);
    }
    if (self.artifact.isDynamicLibrary() and
        self.artifact.target.isWindows() and
        self.artifact.emit_implib != .no_emit)
    {
        const full_src_path = self.artifact.getOutputLibSource().getPath(src_builder);
        const full_implib_path = dest_builder.getInstallPath(self.dest_dir, self.artifact.out_lib_filename);
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_implib_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_implib_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }
    if (self.pdb_dir) |pdb_dir| {
        const full_src_path = self.artifact.getOutputPdbSource().getPath(src_builder);
        const full_pdb_path = dest_builder.getInstallPath(pdb_dir, self.artifact.out_pdb_filename);
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_pdb_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_pdb_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }
    if (self.h_dir) |h_dir| {
        const full_src_path = self.artifact.getOutputHSource().getPath(src_builder);
        const full_h_path = dest_builder.getInstallPath(h_dir, self.artifact.out_h_filename);
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_h_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_h_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }
    self.artifact.installed_path = full_dest_path;
    step.result_cached = all_cached;
}
