//! Fail the build with a given message.
const std = @import("std");
const Step = std.Build.Step;
const Fail = @This();

step: Step,
error_msg: []const u8,

pub const base_id: Step.Id = .fail;

pub fn create(owner: *std.Build, error_msg: []const u8) *Fail {
    const fail = owner.allocator.create(Fail) catch @panic("OOM");

    fail.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "fail",
            .owner = owner,
            .makeFn = make,
        }),
        .error_msg = owner.dupe(error_msg),
    };

    return fail;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options; // No progress to report.

    const fail: *Fail = @fieldParentPtr("step", step);

    try step.result_error_msgs.append(step.owner.allocator, fail.error_msg);

    return error.MakeFailed;
}
