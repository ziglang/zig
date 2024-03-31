const std = @import("std");
const fs = std.fs;
const Step = std.Build.Step;
const RemoveDir = @This();

pub const base_id = .remove_dir;

step: Step,
dir_path: []const u8,

pub fn create(owner: *std.Build, dir_path: []const u8) *RemoveDir {
    const self = owner.allocator.create(RemoveDir) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = .remove_dir,
            .name = owner.fmt("RemoveDir {s}", .{dir_path}),
            .owner = owner,
            .makeFn = make,
        }),
        .dir_path = owner.dupePath(dir_path),
    };
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    // TODO update progress node while walking file system.
    // Should the standard library support this use case??
    _ = prog_node;

    const b = step.owner;
    const self: *RemoveDir = @fieldParentPtr("step", step);

    b.build_root.handle.deleteTree(self.dir_path) catch |err| {
        if (b.build_root.path) |base| {
            return step.fail("unable to recursively delete path '{s}/{s}': {s}", .{
                base, self.dir_path, @errorName(err),
            });
        } else {
            return step.fail("unable to recursively delete path '{s}': {s}", .{
                self.dir_path, @errorName(err),
            });
        }
    };
}
