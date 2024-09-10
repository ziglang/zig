//! Writes data to paths relative to the package root, effectively mutating the
//! package's source files. Be careful with the latter functionality; it should
//! not be used during the normal build process, but as a utility run by a
//! developer with intention to update source files, which will then be
//! committed to version control.
const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const ArrayList = std.ArrayList;
const UpdateSourceFiles = @This();

step: Step,
output_source_files: std.ArrayListUnmanaged(OutputSourceFile),

pub const base_id: Step.Id = .update_source_files;

pub const OutputSourceFile = struct {
    contents: Contents,
    sub_path: []const u8,
};

pub const Contents = union(enum) {
    bytes: []const u8,
    copy: std.Build.LazyPath,
};

pub fn create(owner: *std.Build) *UpdateSourceFiles {
    const usf = owner.allocator.create(UpdateSourceFiles) catch @panic("OOM");
    usf.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "UpdateSourceFiles",
            .owner = owner,
            .makeFn = make,
        }),
        .output_source_files = .{},
    };
    return usf;
}

/// A path relative to the package root.
///
/// Be careful with this because it updates source files. This should not be
/// used as part of the normal build process, but as a utility occasionally
/// run by a developer with intent to modify source files and then commit
/// those changes to version control.
pub fn addCopyFileToSource(usf: *UpdateSourceFiles, source: std.Build.LazyPath, sub_path: []const u8) void {
    const b = usf.step.owner;
    usf.output_source_files.append(b.allocator, .{
        .contents = .{ .copy = source },
        .sub_path = sub_path,
    }) catch @panic("OOM");
    source.addStepDependencies(&usf.step);
}

/// A path relative to the package root.
///
/// Be careful with this because it updates source files. This should not be
/// used as part of the normal build process, but as a utility occasionally
/// run by a developer with intent to modify source files and then commit
/// those changes to version control.
pub fn addBytesToSource(usf: *UpdateSourceFiles, bytes: []const u8, sub_path: []const u8) void {
    const b = usf.step.owner;
    usf.output_source_files.append(b.allocator, .{
        .contents = .{ .bytes = bytes },
        .sub_path = sub_path,
    }) catch @panic("OOM");
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const usf: *UpdateSourceFiles = @fieldParentPtr("step", step);

    var any_miss = false;
    for (usf.output_source_files.items) |output_source_file| {
        if (fs.path.dirname(output_source_file.sub_path)) |dirname| {
            b.build_root.handle.makePath(dirname) catch |err| {
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.build_root, dirname, @errorName(err),
                });
            };
        }
        switch (output_source_file.contents) {
            .bytes => |bytes| {
                b.build_root.handle.writeFile(.{ .sub_path = output_source_file.sub_path, .data = bytes }) catch |err| {
                    return step.fail("unable to write file '{}{s}': {s}", .{
                        b.build_root, output_source_file.sub_path, @errorName(err),
                    });
                };
                any_miss = true;
            },
            .copy => |file_source| {
                if (!step.inputs.populated()) try step.addWatchInput(file_source);

                const source_path = file_source.getPath2(b, step);
                const prev_status = fs.Dir.updateFile(
                    fs.cwd(),
                    source_path,
                    b.build_root.handle,
                    output_source_file.sub_path,
                    .{},
                ) catch |err| {
                    return step.fail("unable to update file from '{s}' to '{}{s}': {s}", .{
                        source_path, b.build_root, output_source_file.sub_path, @errorName(err),
                    });
                };
                any_miss = any_miss or prev_status == .stale;
            },
        }
    }

    step.result_cached = !any_miss;
}
