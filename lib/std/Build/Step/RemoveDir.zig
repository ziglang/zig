const std = @import("std");
const fs = std.fs;
const Step = std.Build.Step;
const RemoveDir = @This();
const LazyPath = std.Build.LazyPath;

pub const base_id: Step.Id = .remove_dir;

step: Step,
doomed_path: LazyPath,

pub fn create(owner: *std.Build, doomed_path: LazyPath) *RemoveDir {
    const remove_dir = owner.allocator.create(RemoveDir) catch @panic("OOM");
    remove_dir.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("RemoveDir {s}", .{doomed_path.getDisplayName()}),
            .owner = owner,
            .makeFn = make,
        }),
        .doomed_path = doomed_path.dupe(owner),
    };
    return remove_dir;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;

    const b = step.owner;
    const remove_dir: *RemoveDir = @fieldParentPtr("step", step);

    step.clearWatchInputs();
    try step.addWatchInput(remove_dir.doomed_path);

    const full_doomed_path = remove_dir.doomed_path.getPath2(b, step);

    b.build_root.handle.deleteTree(full_doomed_path) catch |err| {
        if (b.build_root.path) |base| {
            return step.fail("unable to recursively delete path '{s}/{s}': {s}", .{
                base, full_doomed_path, @errorName(err),
            });
        } else {
            return step.fail("unable to recursively delete path '{s}': {s}", .{
                full_doomed_path, @errorName(err),
            });
        }
    };
}
