const std = @import("../std.zig");
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const InstallDir = std.build.InstallDir;

pub const base_id = .install_artifact;

step: Step,
builder: *Builder,
artifact: *LibExeObjStep,
dest_dir: InstallDir,
pdb_dir: ?InstallDir,
h_dir: ?InstallDir,

const Self = @This();

pub fn create(builder: *Builder, artifact: *LibExeObjStep) *Self {
    if (artifact.install_step) |s| return s;

    const self = builder.allocator.create(Self) catch unreachable;
    self.* = Self{
        .builder = builder,
        .step = Step.init(.install_artifact, builder.fmt("install {s}", .{artifact.step.name}), builder.allocator, make),
        .artifact = artifact,
        .dest_dir = artifact.override_dest_dir orelse switch (artifact.kind) {
            .obj => @panic("Cannot install a .obj build artifact."),
            .@"test" => @panic("Cannot install a test build artifact, use addTestExe instead."),
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
    const self = @fieldParentPtr(Self, "step", step);
    const builder = self.builder;

    const full_dest_path = builder.getInstallPath(self.dest_dir, self.artifact.out_filename);
    try builder.updateFile(self.artifact.getOutputSource().getPath(builder), full_dest_path);
    if (self.artifact.isDynamicLibrary() and self.artifact.version != null and self.artifact.target.wantSharedLibSymLinks()) {
        try LibExeObjStep.doAtomicSymLinks(builder.allocator, full_dest_path, self.artifact.major_only_filename.?, self.artifact.name_only_filename.?);
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
        const full_pdb_path = builder.getInstallPath(h_dir, self.artifact.out_h_filename);
        try builder.updateFile(self.artifact.getOutputHSource().getPath(builder), full_pdb_path);
    }
    self.artifact.installed_path = full_dest_path;
}
