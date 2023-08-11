const std = @import("std");
const Step = std.Build.Step;
const InstallDir = std.Build.InstallDir;
const InstallArtifact = @This();
const fs = std.fs;
const LazyPath = std.Build.LazyPath;

step: Step,

dest_dir: ?InstallDir,
dest_sub_path: []const u8,
emitted_bin: ?LazyPath,

implib_dir: ?InstallDir,
emitted_implib: ?LazyPath,

pdb_dir: ?InstallDir,
emitted_pdb: ?LazyPath,

h_dir: ?InstallDir,
emitted_h: ?LazyPath,

dylib_symlinks: ?DylibSymlinkInfo,

artifact: *Step.Compile,

const DylibSymlinkInfo = struct {
    major_only_filename: []const u8,
    name_only_filename: []const u8,
};

pub const base_id = .install_artifact;

pub const Options = struct {
    /// Which installation directory to put the main output file into.
    dest_dir: Dir = .default,
    pdb_dir: Dir = .default,
    h_dir: Dir = .default,
    implib_dir: Dir = .default,

    /// Whether to install symlinks along with dynamic libraries.
    dylib_symlinks: ?bool = null,
    /// If non-null, adds additional path components relative to bin dir, and
    /// overrides the basename of the Compile step for installation purposes.
    dest_sub_path: ?[]const u8 = null,

    pub const Dir = union(enum) {
        disabled,
        default,
        override: InstallDir,
    };
};

pub fn create(owner: *std.Build, artifact: *Step.Compile, options: Options) *InstallArtifact {
    const self = owner.allocator.create(InstallArtifact) catch @panic("OOM");
    const dest_dir: ?InstallDir = switch (options.dest_dir) {
        .disabled => null,
        .default => switch (artifact.kind) {
            .obj => @panic("object files have no standard installation procedure"),
            .exe, .@"test" => InstallDir{ .bin = {} },
            .lib => InstallDir{ .lib = {} },
        },
        .override => |o| o,
    };
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("install {s}", .{artifact.name}),
            .owner = owner,
            .makeFn = make,
        }),
        .dest_dir = dest_dir,
        .pdb_dir = switch (options.pdb_dir) {
            .disabled => null,
            .default => if (artifact.producesPdbFile()) dest_dir else null,
            .override => |o| o,
        },
        .h_dir = switch (options.h_dir) {
            .disabled => null,
            // https://github.com/ziglang/zig/issues/9698
            .default => null,
            //.default => switch (artifact.kind) {
            //    .lib => .header,
            //    else => null,
            //},
            .override => |o| o,
        },
        .implib_dir = switch (options.implib_dir) {
            .disabled => null,
            .default => if (artifact.producesImplib()) dest_dir else null,
            .override => |o| o,
        },

        .dylib_symlinks = if (options.dylib_symlinks orelse (dest_dir != null and
            artifact.isDynamicLibrary() and
            artifact.version != null and
            artifact.target.wantSharedLibSymLinks())) .{
            .major_only_filename = artifact.major_only_filename.?,
            .name_only_filename = artifact.name_only_filename.?,
        } else null,

        .dest_sub_path = options.dest_sub_path orelse artifact.out_filename,

        .emitted_bin = null,
        .emitted_pdb = null,
        .emitted_h = null,
        .emitted_implib = null,

        .artifact = artifact,
    };

    self.step.dependOn(&artifact.step);

    if (self.dest_dir != null) self.emitted_bin = artifact.getEmittedBin();
    if (self.pdb_dir != null) self.emitted_pdb = artifact.getEmittedPdb();
    if (self.h_dir != null) self.emitted_h = artifact.getEmittedH();
    if (self.implib_dir != null) self.emitted_implib = artifact.getEmittedImplib();

    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const self = @fieldParentPtr(InstallArtifact, "step", step);
    const dest_builder = step.owner;
    const cwd = fs.cwd();

    var all_cached = true;

    if (self.dest_dir) |dest_dir| {
        const full_dest_path = dest_builder.getInstallPath(dest_dir, self.dest_sub_path);
        const full_src_path = self.emitted_bin.?.getPath2(step.owner, step);
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_dest_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_dest_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;

        if (self.dylib_symlinks) |dls| {
            try Step.Compile.doAtomicSymLinks(step, full_dest_path, dls.major_only_filename, dls.name_only_filename);
        }

        self.artifact.installed_path = full_dest_path;
    }

    if (self.implib_dir) |implib_dir| {
        const full_src_path = self.emitted_implib.?.getPath2(step.owner, step);
        const full_implib_path = dest_builder.getInstallPath(implib_dir, fs.path.basename(full_src_path));
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_implib_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_implib_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }

    if (self.pdb_dir) |pdb_dir| {
        const full_src_path = self.emitted_pdb.?.getPath2(step.owner, step);
        const full_pdb_path = dest_builder.getInstallPath(pdb_dir, fs.path.basename(full_src_path));
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_pdb_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_pdb_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }

    if (self.h_dir) |h_dir| {
        const full_src_path = self.emitted_h.?.getPath2(step.owner, step);
        const full_h_path = dest_builder.getInstallPath(h_dir, fs.path.basename(full_src_path));
        const p = fs.Dir.updateFile(cwd, full_src_path, cwd, full_h_path, .{}) catch |err| {
            return step.fail("unable to update file from '{s}' to '{s}': {s}", .{
                full_src_path, full_h_path, @errorName(err),
            });
        };
        all_cached = all_cached and p == .fresh;
    }

    step.result_cached = all_cached;
}
