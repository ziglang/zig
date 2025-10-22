//! Utilities shared between compiler sub-commands
const std = @import("std");
const aro = @import("aro");
const ErrorBundle = std.zig.ErrorBundle;

pub fn aroDiagnosticsToErrorBundle(
    d: *const aro.Diagnostics,
    gpa: std.mem.Allocator,
    fail_msg: ?[]const u8,
) !ErrorBundle {
    @branchHint(.cold);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    errdefer bundle.deinit();

    if (fail_msg) |msg| {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString(msg),
        });
    }

    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayList(ErrorBundle.ErrorMessage) = .empty;
    defer cur_notes.deinit(gpa);
    for (d.output.to_list.messages.items) |msg| {
        switch (msg.kind) {
            .off, .warning => {
                // Emit any pending error and clear everything so that notes don't bleed into unassociated errors
                if (cur_err) |err| {
                    try bundle.addRootErrorMessageWithNotes(err, cur_notes.items);
                    cur_err = null;
                }
                cur_notes.clearRetainingCapacity();
                continue;
            },
            .note => if (cur_err == null) continue,
            .@"fatal error", .@"error" => {},
        }

        const src_loc = src_loc: {
            if (msg.location) |location| {
                break :src_loc try bundle.addSourceLocation(.{
                    .src_path = try bundle.addString(location.path),
                    .line = location.line_no - 1, // 1-based -> 0-based
                    .column = location.col - 1, // 1-based -> 0-based
                    .span_start = location.width,
                    .span_main = location.width,
                    .span_end = location.width,
                    .source_line = try bundle.addString(location.line),
                });
            }
            break :src_loc ErrorBundle.SourceLocationIndex.none;
        };

        switch (msg.kind) {
            .@"fatal error", .@"error" => {
                if (cur_err) |err| {
                    try bundle.addRootErrorMessageWithNotes(err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(msg.text),
                    .src_loc = src_loc,
                };
                cur_notes.clearRetainingCapacity();
            },
            .note => {
                cur_err.?.notes_len += 1;
                try cur_notes.append(gpa, .{
                    .msg = try bundle.addString(msg.text),
                    .src_loc = src_loc,
                });
            },
            .off, .warning => unreachable,
        }
    }
    if (cur_err) |err| {
        try bundle.addRootErrorMessageWithNotes(err, cur_notes.items);
    }

    return try bundle.toOwnedBundle("");
}
