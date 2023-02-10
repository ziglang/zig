const std = @import("../std.zig");
const log = std.log;
const fs = std.fs;
const Step = std.Build.Step;
const RemoveDirStep = @This();

pub const base_id = .remove_dir;

step: Step,
builder: *std.Build,
dir_path: []const u8,

pub fn init(builder: *std.Build, dir_path: []const u8) RemoveDirStep {
    return RemoveDirStep{
        .builder = builder,
        .step = Step.init(.remove_dir, builder.fmt("RemoveDir {s}", .{dir_path}), builder.allocator, make),
        .dir_path = builder.dupePath(dir_path),
    };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(RemoveDirStep, "step", step);

    const full_path = self.builder.pathFromRoot(self.dir_path);
    fs.cwd().deleteTree(full_path) catch |err| {
        log.err("Unable to remove {s}: {s}", .{ full_path, @errorName(err) });
        return err;
    };
}
