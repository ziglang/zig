const std = @import("std");
const fs = std.fs;
const Step = std.Build.Step;
const RemoveDir = @This();

pub const base_id: Step.Id = .remove_dir;

step: Step,
dir_path: []const u8,

pub fn create(owner: *std.Build, dir_path: []const u8) *RemoveDir {
    const remove_dir = owner.allocator.create(RemoveDir) catch @panic("OOM");
    remove_dir.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("RemoveDir {s}", .{dir_path}),
            .owner = owner,
            .makeFn = make,
        }),
        .dir_path = owner.dupePath(dir_path),
    };
    return remove_dir;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    // TODO update progress node while walking file system.
    // Should the standard library support this use case??
    _ = prog_node;

    const b = step.owner;
    const remove_dir: *RemoveDir = @fieldParentPtr("step", step);

    b.build_root.handle.deleteTree(remove_dir.dir_path) catch |err| {
        if (b.build_root.path) |base| {
            return step.fail("unable to recursively delete path '{s}/{s}': {s}", .{
                base, remove_dir.dir_path, @errorName(err),
            });
        } else {
            return step.fail("unable to recursively delete path '{s}': {s}", .{
                remove_dir.dir_path, @errorName(err),
            });
        }
    };
}
