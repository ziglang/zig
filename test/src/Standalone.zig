b: *std.Build,
step: *Step,
test_index: usize,
test_filter: ?[]const u8,
optimize_modes: []const OptimizeMode,
skip_non_native: bool,
enable_macos_sdk: bool,
target: std.zig.CrossTarget,
omit_stage2: bool,
enable_darling: bool = false,
enable_qemu: bool = false,
enable_rosetta: bool = false,
enable_wasmtime: bool = false,
enable_wine: bool = false,
enable_symlinks_windows: bool,

pub fn addC(self: *Standalone, root_src: []const u8) void {
    self.addAllArgs(root_src, true);
}

pub fn add(self: *Standalone, root_src: []const u8) void {
    self.addAllArgs(root_src, false);
}

pub fn addBuildFile(self: *Standalone, build_file: []const u8, features: struct {
    build_modes: bool = false,
    cross_targets: bool = false,
    requires_macos_sdk: bool = false,
    requires_stage2: bool = false,
    use_emulation: bool = false,
    requires_symlinks: bool = false,
    extra_argv: []const []const u8 = &.{},
}) void {
    const b = self.b;

    if (features.requires_macos_sdk and !self.enable_macos_sdk) return;
    if (features.requires_stage2 and self.omit_stage2) return;
    if (features.requires_symlinks and !self.enable_symlinks_windows and builtin.os.tag == .windows) return;

    const annotated_case_name = b.fmt("build {s}", .{build_file});
    if (self.test_filter) |filter| {
        if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
    }

    var zig_args = ArrayList([]const u8).init(b.allocator);
    const rel_zig_exe = fs.path.relative(b.allocator, b.build_root.path orelse ".", b.zig_exe) catch unreachable;
    zig_args.append(rel_zig_exe) catch unreachable;
    zig_args.append("build") catch unreachable;

    // TODO: fix the various non-concurrency-safe issues in zig's standalone tests,
    // and then remove this!
    zig_args.append("-j1") catch @panic("OOM");

    zig_args.append("--build-file") catch unreachable;
    zig_args.append(b.pathFromRoot(build_file)) catch unreachable;

    zig_args.appendSlice(features.extra_argv) catch unreachable;

    zig_args.append("test") catch unreachable;

    if (b.verbose) {
        zig_args.append("--verbose") catch unreachable;
    }

    if (features.cross_targets and !self.target.isNative()) {
        const target_triple = self.target.zigTriple(b.allocator) catch unreachable;
        const target_arg = fmt.allocPrint(b.allocator, "-Dtarget={s}", .{target_triple}) catch unreachable;
        zig_args.append(target_arg) catch unreachable;
    }

    if (features.use_emulation) {
        if (self.enable_darling) {
            zig_args.append("-fdarling") catch unreachable;
        }
        if (self.enable_qemu) {
            zig_args.append("-fqemu") catch unreachable;
        }
        if (self.enable_rosetta) {
            zig_args.append("-frosetta") catch unreachable;
        }
        if (self.enable_wasmtime) {
            zig_args.append("-fwasmtime") catch unreachable;
        }
        if (self.enable_wine) {
            zig_args.append("-fwine") catch unreachable;
        }
    }

    const optimize_modes = if (features.build_modes) self.optimize_modes else &[1]OptimizeMode{.Debug};
    for (optimize_modes) |optimize_mode| {
        const arg = switch (optimize_mode) {
            .Debug => "",
            .ReleaseFast => "-Doptimize=ReleaseFast",
            .ReleaseSafe => "-Doptimize=ReleaseSafe",
            .ReleaseSmall => "-Doptimize=ReleaseSmall",
        };
        const zig_args_base_len = zig_args.items.len;
        if (arg.len > 0)
            zig_args.append(arg) catch unreachable;
        defer zig_args.resize(zig_args_base_len) catch unreachable;

        const run_cmd = b.addSystemCommand(zig_args.items);
        self.step.dependOn(&run_cmd.step);
    }
}

pub fn addAllArgs(self: *Standalone, root_src: []const u8, link_libc: bool) void {
    const b = self.b;

    for (self.optimize_modes) |optimize| {
        const annotated_case_name = fmt.allocPrint(self.b.allocator, "build {s} ({s})", .{
            root_src,
            @tagName(optimize),
        }) catch unreachable;
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) continue;
        }

        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = .{ .path = root_src },
            .optimize = optimize,
            .target = .{},
        });
        if (link_libc) {
            exe.linkSystemLibrary("c");
        }

        self.step.dependOn(&exe.step);
    }
}

const Standalone = @This();
const std = @import("std");
const builtin = @import("builtin");
const Step = std.Build.Step;
const OptimizeMode = std.builtin.OptimizeMode;
const fmt = std.fmt;
const mem = std.mem;
const ArrayList = std.ArrayList;
const fs = std.fs;
