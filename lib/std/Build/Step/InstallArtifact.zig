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

pub const base_id: Step.Id = .install_artifact;

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
    const install_artifact = owner.allocator.create(InstallArtifact) catch @panic("OOM");
    const dest_dir: ?InstallDir = switch (options.dest_dir) {
        .disabled => null,
        .default => switch (artifact.kind) {
            .obj, .test_obj => @panic("object files have no standard installation procedure"),
            .exe, .@"test" => .bin,
            .lib => if (artifact.isDll()) .bin else .lib,
        },
        .override => |o| o,
    };
    install_artifact.* = .{
        .step = .init(.{
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
            .default => if (artifact.kind == .lib) .header else null,
            .override => |o| o,
        },
        .implib_dir = switch (options.implib_dir) {
            .disabled => null,
            .default => if (artifact.producesImplib()) .lib else null,
            .override => |o| o,
        },

        .dylib_symlinks = if (options.dylib_symlinks orelse (dest_dir != null and
            artifact.isDynamicLibrary() and
            artifact.version != null and
            std.Build.wantSharedLibSymLinks(artifact.rootModuleTarget()))) .{
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

    install_artifact.step.dependOn(&artifact.step);

    if (install_artifact.dest_dir != null) install_artifact.emitted_bin = artifact.getEmittedBin();
    if (install_artifact.pdb_dir != null) install_artifact.emitted_pdb = artifact.getEmittedPdb();
    // https://github.com/ziglang/zig/issues/9698
    //if (install_artifact.h_dir != null) install_artifact.emitted_h = artifact.getEmittedH();
    if (install_artifact.implib_dir != null) install_artifact.emitted_implib = artifact.getEmittedImplib();

    return install_artifact;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const install_artifact: *InstallArtifact = @fieldParentPtr("step", step);
    const b = step.owner;

    var all_cached = true;

    if (install_artifact.dest_dir) |dest_dir| {
        const full_dest_path = b.getInstallPath(dest_dir, install_artifact.dest_sub_path);
        const p = try step.installFile(install_artifact.emitted_bin.?, full_dest_path);
        all_cached = all_cached and p == .fresh;

        if (install_artifact.dylib_symlinks) |dls| {
            try Step.Compile.doAtomicSymLinks(step, full_dest_path, dls.major_only_filename, dls.name_only_filename);
        }

        install_artifact.artifact.installed_path = full_dest_path;
    }

    if (install_artifact.implib_dir) |implib_dir| {
        const full_implib_path = b.getInstallPath(implib_dir, install_artifact.emitted_implib.?.basename(b, step));
        const p = try step.installFile(install_artifact.emitted_implib.?, full_implib_path);
        all_cached = all_cached and p == .fresh;
    }

    if (install_artifact.pdb_dir) |pdb_dir| {
        const full_pdb_path = b.getInstallPath(pdb_dir, install_artifact.emitted_pdb.?.basename(b, step));
        const p = try step.installFile(install_artifact.emitted_pdb.?, full_pdb_path);
        all_cached = all_cached and p == .fresh;
    }

    if (install_artifact.h_dir) |h_dir| {
        if (install_artifact.emitted_h) |emitted_h| {
            const full_h_path = b.getInstallPath(h_dir, emitted_h.basename(b, step));
            const p = try step.installFile(emitted_h, full_h_path);
            all_cached = all_cached and p == .fresh;
        }

        for (install_artifact.artifact.installed_headers.items) |installation| switch (installation) {
            .file => |file| {
                const full_h_path = b.getInstallPath(h_dir, file.dest_rel_path);
                const p = try step.installFile(file.source, full_h_path);
                all_cached = all_cached and p == .fresh;
            },
            .directory => |dir| {
                const src_dir_path = dir.source.getPath3(b, step);
                const full_h_prefix = b.getInstallPath(h_dir, dir.dest_rel_path);

                var src_dir = src_dir_path.root_dir.handle.openDir(src_dir_path.subPathOrDot(), .{ .iterate = true }) catch |err| {
                    return step.fail("unable to open source directory '{f}': {s}", .{
                        src_dir_path, @errorName(err),
                    });
                };
                defer src_dir.close();

                var it = try src_dir.walk(b.allocator);
                next_entry: while (try it.next()) |entry| {
                    for (dir.options.exclude_extensions) |ext| {
                        if (std.mem.endsWith(u8, entry.path, ext)) continue :next_entry;
                    }
                    if (dir.options.include_extensions) |incs| {
                        for (incs) |inc| {
                            if (std.mem.endsWith(u8, entry.path, inc)) break;
                        } else {
                            continue :next_entry;
                        }
                    }

                    const full_dest_path = b.pathJoin(&.{ full_h_prefix, entry.path });
                    switch (entry.kind) {
                        .directory => {
                            try Step.handleVerbose(b, null, &.{ "install", "-d", full_dest_path });
                            const p = try step.installDir(full_dest_path);
                            all_cached = all_cached and p == .existed;
                        },
                        .file => {
                            const p = try step.installFile(try dir.source.join(b.allocator, entry.path), full_dest_path);
                            all_cached = all_cached and p == .fresh;
                        },
                        else => continue,
                    }
                }
            },
        };
    }

    step.result_cached = all_cached;
}
