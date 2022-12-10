const std = @import("../std.zig");
const mem = std.mem;
const fs = std.fs;
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const InstallDir = std.build.InstallDir;
const InstallDirStep = @This();

step: Step,
builder: *Builder,
options: Options,

pub const base_id = .install_dir;

pub const Options = struct {
    source_dir: []const u8,
    install_dir: InstallDir,
    install_subdir: []const u8,
    /// File paths which end in any of these suffixes will be excluded
    /// from being installed.
    exclude_extensions: []const []const u8 = &.{},
    /// File paths which end in any of these suffixes will result in
    /// empty files being installed. This is mainly intended for large
    /// test.zig files in order to prevent needless installation bloat.
    /// However if the files were not present at all, then
    /// `@import("test.zig")` would be a compile error.
    blank_extensions: []const []const u8 = &.{},

    fn dupe(self: Options, b: *Builder) Options {
        return .{
            .source_dir = b.dupe(self.source_dir),
            .install_dir = self.install_dir.dupe(b),
            .install_subdir = b.dupe(self.install_subdir),
            .exclude_extensions = b.dupeStrings(self.exclude_extensions),
            .blank_extensions = b.dupeStrings(self.blank_extensions),
        };
    }
};

pub fn init(
    builder: *Builder,
    options: Options,
) InstallDirStep {
    builder.pushInstalledFile(options.install_dir, options.install_subdir);
    return InstallDirStep{
        .builder = builder,
        .step = Step.init(.install_dir, builder.fmt("install {s}/", .{options.source_dir}), builder.allocator, make),
        .options = options.dupe(builder),
    };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallDirStep, "step", step);
    const dest_prefix = self.builder.getInstallPath(self.options.install_dir, self.options.install_subdir);
    const full_src_dir = self.builder.pathFromRoot(self.options.source_dir);
    var src_dir = try std.fs.cwd().openIterableDir(full_src_dir, .{});
    defer src_dir.close();
    var it = try src_dir.walk(self.builder.allocator);
    next_entry: while (try it.next()) |entry| {
        for (self.options.exclude_extensions) |ext| {
            if (mem.endsWith(u8, entry.path, ext)) {
                continue :next_entry;
            }
        }

        const full_path = self.builder.pathJoin(&.{
            full_src_dir, entry.path,
        });

        const dest_path = self.builder.pathJoin(&.{
            dest_prefix, entry.path,
        });

        switch (entry.kind) {
            .Directory => try fs.cwd().makePath(dest_path),
            .File => {
                for (self.options.blank_extensions) |ext| {
                    if (mem.endsWith(u8, entry.path, ext)) {
                        try self.builder.truncateFile(dest_path);
                        continue :next_entry;
                    }
                }

                try self.builder.updateFile(full_path, dest_path);
            },
            else => continue,
        }
    }
}
