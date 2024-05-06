const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const InstallDir = std.Build.InstallDir;
const InstallDirStep = @This();

step: Step,
options: Options,

pub const base_id = .install_dir;

pub const Options = struct {
    source_dir: LazyPath,
    install_dir: InstallDir,
    install_subdir: []const u8,
    /// File paths which end in any of these suffixes will be excluded
    /// from being installed.
    exclude_extensions: []const []const u8 = &.{},
    /// Only file paths which end in any of these suffixes will be included
    /// in installation. `null` means all suffixes are valid for this option.
    /// `exclude_extensions` take precedence over `include_extensions`
    include_extensions: ?[]const []const u8 = null,
    /// File paths which end in any of these suffixes will result in
    /// empty files being installed. This is mainly intended for large
    /// test.zig files in order to prevent needless installation bloat.
    /// However if the files were not present at all, then
    /// `@import("test.zig")` would be a compile error.
    blank_extensions: []const []const u8 = &.{},

    fn dupe(self: Options, b: *std.Build) Options {
        return .{
            .source_dir = self.source_dir.dupe(b),
            .install_dir = self.install_dir.dupe(b),
            .install_subdir = b.dupe(self.install_subdir),
            .exclude_extensions = b.dupeStrings(self.exclude_extensions),
            .include_extensions = if (self.include_extensions) |incs| b.dupeStrings(incs) else null,
            .blank_extensions = b.dupeStrings(self.blank_extensions),
        };
    }
};

pub fn create(owner: *std.Build, options: Options) *InstallDirStep {
    owner.pushInstalledFile(options.install_dir, options.install_subdir);
    const self = owner.allocator.create(InstallDirStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = .install_dir,
            .name = owner.fmt("install {s}/", .{options.source_dir.getDisplayName()}),
            .owner = owner,
            .makeFn = make,
        }),
        .options = options.dupe(owner),
    };
    options.source_dir.addStepDependencies(&self.step);
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const self: *InstallDirStep = @fieldParentPtr("step", step);
    const arena = b.allocator;
    const dest_prefix = b.getInstallPath(self.options.install_dir, self.options.install_subdir);
    const src_dir_path = self.options.source_dir.getPath2(b, step);
    var src_dir = b.build_root.handle.openDir(src_dir_path, .{ .iterate = true }) catch |err| {
        return step.fail("unable to open source directory '{}{s}': {s}", .{
            b.build_root, src_dir_path, @errorName(err),
        });
    };
    defer src_dir.close();
    var it = try src_dir.walk(arena);
    var all_cached = true;
    next_entry: while (try it.next()) |entry| {
        for (self.options.exclude_extensions) |ext| {
            if (mem.endsWith(u8, entry.path, ext)) {
                continue :next_entry;
            }
        }
        if (self.options.include_extensions) |incs| {
            var found = false;
            for (incs) |inc| {
                if (mem.endsWith(u8, entry.path, inc)) {
                    found = true;
                    break;
                }
            }
            if (!found) continue :next_entry;
        }

        // relative to src build root
        const src_sub_path = try fs.path.join(arena, &.{ src_dir_path, entry.path });
        const dest_path = try fs.path.join(arena, &.{ dest_prefix, entry.path });
        const cwd = fs.cwd();

        switch (entry.kind) {
            .directory => try cwd.makePath(dest_path),
            .file => {
                for (self.options.blank_extensions) |ext| {
                    if (mem.endsWith(u8, entry.path, ext)) {
                        try b.truncateFile(dest_path);
                        continue :next_entry;
                    }
                }

                const prev_status = fs.Dir.updateFile(
                    b.build_root.handle,
                    src_sub_path,
                    cwd,
                    dest_path,
                    .{},
                ) catch |err| {
                    return step.fail("unable to update file from '{}{s}' to '{s}': {s}", .{
                        b.build_root, src_sub_path, dest_path, @errorName(err),
                    });
                };
                all_cached = all_cached and prev_status == .fresh;
            },
            else => continue,
        }
    }

    step.result_cached = all_cached;
}
