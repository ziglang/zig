const std = @import("../std.zig");
const Step = std.Build.Step;
const CompileStep = std.Build.CompileStep;
const InstallDir = std.Build.InstallDir;
const InstallArtifactStep = @This();

pub const base_id = .install_artifact;

step: Step,
builder: *std.Build,
artifact: *CompileStep,
dest_dir: InstallDir,
pdb_dir: ?InstallDir,
h_dir: ?InstallDir,

pub fn create(builder: *std.Build, artifact: *CompileStep) *InstallArtifactStep {
    if (artifact.install_step) |s| return s;

    const self = builder.allocator.create(InstallArtifactStep) catch @panic("OOM");
    self.* = InstallArtifactStep{
        .builder = builder,
        .step = Step.init(.install_artifact, builder.fmt("install {s}", .{artifact.step.name}), builder.allocator, make),
        .artifact = artifact,
        .dest_dir = artifact.override_dest_dir orelse switch (artifact.kind) {
            .obj => @panic("Cannot install a .obj build artifact."),
            .@"test" => @panic("Cannot install a .test build artifact, use .test_exe instead."),
            .exe, .test_exe => InstallDir{ .bin = {} },
            .lib => InstallDir{ .lib = {} },
        },
        .pdb_dir = if (artifact.producesPdbFile()) blk: {
            if (artifact.kind == .exe or artifact.kind == .test_exe) {
                break :blk InstallDir{ .bin = {} };
            } else {
                break :blk InstallDir{ .lib = {} };
            }
        } else null,
        .h_dir = if (artifact.kind == .lib and artifact.emit_h) .header else null,
    };
    self.step.dependOn(&artifact.step);
    artifact.install_step = self;

    builder.pushInstalledFile(self.dest_dir, artifact.out_filename);
    if (self.artifact.isDynamicLibrary()) {
        if (artifact.major_only_filename) |name| {
            builder.pushInstalledFile(.lib, name);
        }
        if (artifact.name_only_filename) |name| {
            builder.pushInstalledFile(.lib, name);
        }
        if (self.artifact.target.isWindows()) {
            builder.pushInstalledFile(.lib, artifact.out_lib_filename);
        }
    }
    if (self.pdb_dir) |pdb_dir| {
        builder.pushInstalledFile(pdb_dir, artifact.out_pdb_filename);
    }
    if (self.h_dir) |h_dir| {
        builder.pushInstalledFile(h_dir, artifact.out_h_filename);
    }
    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallArtifactStep, "step", step);
    const builder = self.builder;

    const full_dest_path = builder.getInstallPath(self.dest_dir, self.artifact.out_filename);
    try builder.updateFile(self.artifact.getOutputSource().getPath(builder), full_dest_path);
    if (self.artifact.isDynamicLibrary() and self.artifact.version != null and self.artifact.target.wantSharedLibSymLinks()) {
        try CompileStep.doAtomicSymLinks(builder.allocator, full_dest_path, self.artifact.major_only_filename.?, self.artifact.name_only_filename.?);
    }
    if (self.artifact.isDynamicLibrary() and self.artifact.target.isWindows() and self.artifact.emit_implib != .no_emit) {
        const full_implib_path = builder.getInstallPath(self.dest_dir, self.artifact.out_lib_filename);
        try builder.updateFile(self.artifact.getOutputLibSource().getPath(builder), full_implib_path);
    }
    if (self.pdb_dir) |pdb_dir| {
        const full_pdb_path = builder.getInstallPath(pdb_dir, self.artifact.out_pdb_filename);
        try builder.updateFile(self.artifact.getOutputPdbSource().getPath(builder), full_pdb_path);
    }
    if (self.h_dir) |h_dir| {
        const full_h_path = builder.getInstallPath(h_dir, self.artifact.out_h_filename);
        try builder.updateFile(self.artifact.getOutputHSource().getPath(builder), full_h_path);
    }
    self.artifact.installed_path = full_dest_path;
}
